#!/usr/bin/env python3
"""Add resumable, versioned resource loading to a generated Godot Web page."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


LOADER_STYLE = """
#status-detail {
	color: #d5def2;
	font-family: system-ui, sans-serif;
	font-size: 14px;
	line-height: 1.6;
	margin: 18px 24px 0;
	max-width: 420px;
	text-align: center;
}
#status-retry {
	background: #245bd8;
	border: 1px solid #7ca4ff;
	border-radius: 8px;
	color: white;
	cursor: pointer;
	font-size: 15px;
	margin-top: 18px;
	padding: 10px 24px;
}
#status-retry[hidden] { display: none; }
"""

LOADER_SCRIPT = r"""
(function () {
	const statusOverlay = document.getElementById('status');
	const statusProgress = document.getElementById('status-progress');
	const statusNotice = document.getElementById('status-notice');
	const statusSplash = document.getElementById('status-splash');
	const statusDetail = document.getElementById('status-detail');
	const retryButton = document.getElementById('status-retry');
	const resourceNames = ['play.pck', 'play.wasm'];
	const cachePrefix = 'blackhole-city-web-';
	const cacheName = cachePrefix + GAME_VERSION;
	const nativeFetch = window.fetch.bind(window);
	const preloaded = new Map();
	function publishedName(name) {
		const dot = name.lastIndexOf('.');
		return name.slice(0, dot) + '.' + GAME_VERSION + name.slice(dot);
	}
	const resourceURLs = new Map(resourceNames.map((name) => {
		const url = new URL(publishedName(name), document.baseURI);
		url.searchParams.set('v', GAME_VERSION);
		return [name, url.href];
	}));
	let booting = false;
	let engineAttempted = false;
	let completedBytes = 0;
	let retryDetail = '';
	const diagnosticStorageKey = 'blackhole-city-runtime-v1';
	let previousDiagnostic = null;
	try {
		const stored = window.sessionStorage.getItem(diagnosticStorageKey);
		previousDiagnostic = stored ? JSON.parse(stored) : null;
	} catch (_) {
		previousDiagnostic = null;
	}
	const previousPhase = previousDiagnostic && typeof previousDiagnostic.phase === 'string'
		? previousDiagnostic.phase : '';
	const wasInterrupted = previousDiagnostic && (previousDiagnostic.abnormal === true ||
		['loading', 'running', 'runtime-error', 'unhandled-rejection', 'context-lost'].includes(previousPhase));
	const interruptionCount = wasInterrupted
		? Math.min(9, Math.max(0, Number(previousDiagnostic.interruptionCount) || 0) + 1) : 0;
	const diagnostic = {
		version: GAME_VERSION,
		phase: 'loading',
		startedAt: new Date().toISOString(),
		timeOrigin: performance.timeOrigin,
		interruptionCount: interruptionCount,
		safeMode: interruptionCount > 0,
		tabId: window.crypto && typeof window.crypto.randomUUID === 'function'
			? window.crypto.randomUUID() : String(Date.now()) + '-' + String(Math.random()),
		duplicateTab: false,
		abnormal: false,
		lastEvent: null,
		lastError: null,
		lastSwallow: null,
		gameplay: null,
	};
	let recoveryBlocked = interruptionCount >= 2;

	function persistDiagnostic() {
		try {
			window.sessionStorage.setItem(diagnosticStorageKey, JSON.stringify(diagnostic));
		} catch (_) {
			// Storage can be unavailable in private or embedded browsing contexts.
		}
	}

	function errorDetail(error) {
		return {
			message: String(error && error.message ? error.message : error).slice(0, 500),
			source: String(error && error.filename ? error.filename : '').slice(0, 300),
			line: Number(error && error.lineno ? error.lineno : 0),
		};
	}

	function recordBrowserEvent(type, payload) {
		diagnostic.lastEvent = {
			type: type,
			at: new Date().toISOString(),
			payload: payload || null,
		};
		persistDiagnostic();
	}

	window.BlackholeDiagnostics = {
		get safeMode() { return diagnostic.safeMode; },
		publish: function (type, payload) {
			diagnostic.phase = 'running';
			if (type === 'gameplay') {
				diagnostic.gameplay = payload;
			} else if (type === 'swallow') {
				diagnostic.lastSwallow = payload;
				if (diagnostic.gameplay) {
					diagnostic.gameplay.last_swallow = payload;
				}
			}
			recordBrowserEvent(type, payload);
		},
		snapshot: function () {
			return JSON.stringify({current: diagnostic, previous: previousDiagnostic});
		},
	};
	persistDiagnostic();
	window.addEventListener('error', function (event) {
		diagnostic.phase = 'runtime-error';
		diagnostic.abnormal = true;
		diagnostic.lastError = errorDetail(event);
		recordBrowserEvent('error', diagnostic.lastError);
	});
	window.addEventListener('unhandledrejection', function (event) {
		diagnostic.phase = 'unhandled-rejection';
		diagnostic.abnormal = true;
		diagnostic.lastError = errorDetail(event.reason);
		recordBrowserEvent('unhandledrejection', diagnostic.lastError);
	});
	const gameCanvas = document.getElementById('canvas');
	let tabChannel = null;

	function configureSafeContext() {
		if (!gameCanvas || !diagnostic.safeMode) {
			return;
		}
		const originalGetContext = HTMLCanvasElement.prototype.getContext;
		HTMLCanvasElement.prototype.getContext = function (type, attributes) {
			if (this === gameCanvas && type === 'webgl2') {
				attributes = Object.assign({}, attributes, {antialias: false});
			}
			return originalGetContext.call(this, type, attributes);
		};
	}

	function probePreviousTab() {
		return new Promise(function (resolve) {
			let probe = null;
			let settled = false;
			let timer = 0;
			function finish(duplicated) {
				if (settled) {
					return;
				}
				settled = true;
				window.clearTimeout(timer);
				if (probe) {
					probe.close();
				}
				resolve(duplicated);
			}
			try {
				probe = new BroadcastChannel('blackhole-city-tab-' + previousDiagnostic.tabId);
				probe.onmessage = function (event) {
					if (event.data && event.data.type === 'pong') {
						finish(true);
					}
				};
				timer = window.setTimeout(function () { finish(false); }, 200);
				probe.postMessage({type: 'ping'});
			} catch (_) {
				finish(false);
			}
		});
	}

	async function prepareTabSession() {
		if ('BroadcastChannel' in window) {
			try {
				tabChannel = new BroadcastChannel('blackhole-city-tab-' + diagnostic.tabId);
				tabChannel.onmessage = function (event) {
					if (event.data && event.data.type === 'ping') {
						tabChannel.postMessage({type: 'pong'});
					}
				};
			} catch (_) {
				tabChannel = null;
			}
			const navigationEntry = performance.getEntriesByType('navigation')[0];
			if (wasInterrupted && navigationEntry && navigationEntry.type === 'navigate' &&
				previousDiagnostic.tabId && await probePreviousTab()) {
				diagnostic.interruptionCount = 0;
				diagnostic.safeMode = false;
				diagnostic.duplicateTab = true;
				recoveryBlocked = false;
				recordBrowserEvent('duplicate-tab');
			}
		}
	}

	if (gameCanvas) {
		gameCanvas.addEventListener('webglcontextlost', function () {
			diagnostic.phase = 'context-lost';
			diagnostic.abnormal = true;
			diagnostic.lastError = {message: 'WebGL context lost', source: '', line: 0};
			recordBrowserEvent('webglcontextlost');
		});
		gameCanvas.addEventListener('webglcontextrestored', function () {
			diagnostic.phase = 'running';
			recordBrowserEvent('webglcontextrestored');
		});
	}
	window.addEventListener('pagehide', function () {
		if (!diagnostic.abnormal) {
			diagnostic.phase = 'pagehide';
		}
		recordBrowserEvent('pagehide', {faultPreserved: diagnostic.abnormal});
	});
	window.addEventListener('pageshow', function (event) {
		if (event.persisted) {
			diagnostic.phase = 'running';
			recordBrowserEvent('pageshow', {persisted: true});
		}
	});

	function formatMB(bytes) {
		return (bytes / 1048576).toFixed(1);
	}

	function resourceSize(name) {
		return GODOT_CONFIG.fileSizes[name];
	}

	const totalBytes = resourceNames.reduce((sum, name) => sum + resourceSize(name), 0);

	function showProgress() {
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = 'block';
		statusNotice.style.display = 'none';
		statusSplash.style.removeProperty('display');
		statusDetail.style.display = 'block';
		retryButton.hidden = true;
	}

	function updateProgress(received) {
		const loaded = Math.min(completedBytes + received, totalBytes);
		statusProgress.max = totalBytes;
		statusProgress.value = loaded;
		const percent = Math.floor(loaded * 100 / totalBytes);
		statusDetail.textContent = '下载游戏资源 ' + percent + '% · ' +
			formatMB(loaded) + ' / ' + formatMB(totalBytes) + ' MB' + retryDetail +
			(diagnostic.safeMode ? ' · 稳定模式' : '');
	}

	function showRecoveryStop() {
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = 'none';
		statusSplash.style.display = 'none';
		statusNotice.style.display = 'block';
		statusNotice.textContent = '浏览器连续中断，已暂停自动启动';
		const previousError = previousDiagnostic && previousDiagnostic.lastError
			? '；最近记录：' + previousDiagnostic.lastError.message : '';
		const previousGameplay = previousDiagnostic && previousDiagnostic.gameplay;
		const progressDetail = previousGameplay
			? '；上次进度 Lv.' + previousGameplay.level + '，得分 ' + previousGameplay.score : '';
		statusDetail.textContent = '已保留本标签页的运行与吞噬进度，避免继续反复重载' + progressDetail + previousError +
			'。点击按钮使用稳定模式重试；页面不会自动刷新。';
		statusDetail.style.display = 'block';
		retryButton.textContent = '重试稳定模式';
		retryButton.hidden = false;
		diagnostic.phase = 'recovery-blocked';
		recordBrowserEvent('recovery-blocked', {previousPhase: previousPhase});
	}

	function showFailure(error) {
		diagnostic.phase = engineAttempted ? 'engine-failed' : 'load-failed';
		diagnostic.lastError = errorDetail(error);
		recordBrowserEvent(diagnostic.phase, diagnostic.lastError);
		statusOverlay.style.visibility = 'visible';
		statusProgress.style.display = 'none';
		statusSplash.style.display = 'none';
		statusNotice.style.display = 'block';
		statusNotice.textContent = error.message || String(error);
		statusDetail.textContent = engineAttempted
			? '完整资源已保留。点击按钮手动刷新页面并重新初始化；页面不会自动反复刷新。'
			: '页面不会自动反复刷新。检查网络后，可只重试未完成的资源。';
		retryButton.textContent = engineAttempted ? '重新初始化' : '重试加载';
		retryButton.hidden = false;
	}

	function responseFor(name, blob) {
		const type = name.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream';
		return new Response(blob, {
			status: 200,
			headers: {
				'Content-Type': type,
				'Content-Length': String(resourceSize(name)),
				'Cache-Control': 'public, max-age=31536000, immutable',
			},
		});
	}

	function requestedName(input) {
		try {
			const raw = typeof input === 'string' ? input : input.url;
			const url = new URL(raw, document.baseURI);
			if (url.origin !== window.location.origin) {
				return null;
			}
			const name = url.pathname.split('/').pop();
			return resourceNames.includes(name) ? name : null;
		} catch (_) {
			return null;
		}
	}

	function versionedRequestURL(input) {
		const raw = typeof input === 'string' ? input : input.url;
		const url = new URL(raw, document.baseURI);
		const name = url.pathname.split('/').pop();
		if (url.origin === window.location.origin && (resourceNames.includes(name) || name === 'play.js')) {
			return new URL(publishedName(name), document.baseURI).href;
		}
		if (url.origin === window.location.origin && name.startsWith('play.')) {
			url.searchParams.set('v', GAME_VERSION);
		}
		return url.href;
	}

	window.fetch = function (input, init) {
		const name = requestedName(input);
		if (name && preloaded.has(name)) {
			return Promise.resolve(preloaded.get(name).clone());
		}
		const url = versionedRequestURL(input);
		if (input instanceof Request) {
			return nativeFetch(new Request(url, input), init);
		}
		return nativeFetch(url, init);
	};

	async function openCache() {
		if (!('caches' in window)) {
			return null;
		}
		try {
			return await window.caches.open(cacheName);
		} catch (_) {
			return null;
		}
	}

	async function blobMatches(name, blob) {
		if (!window.crypto || !window.crypto.subtle) {
			throw new Error('当前环境无法校验游戏资源完整性');
		}
		const digest = await window.crypto.subtle.digest('SHA-256', await blob.arrayBuffer());
		const actual = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
		return actual === GAME_SHA256[name];
	}

	async function readCached(name, cache) {
		if (!cache) {
			return false;
		}
		try {
			const cached = await cache.match(resourceURLs.get(name));
			if (!cached) {
				return false;
			}
			const blob = await cached.blob();
			if (blob.size !== resourceSize(name) || !await blobMatches(name, blob)) {
				await cache.delete(resourceURLs.get(name));
				return false;
			}
			preloaded.set(name, responseFor(name, blob));
			return true;
		} catch (_) {
			return false;
		}
	}

	function delay(milliseconds) {
		return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
	}

	async function download(name) {
		const expected = resourceSize(name);
		const chunks = [];
		let received = 0;
		const maxAttempts = 8;
		for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
			let reader = null;
			try {
				const headers = {};
				if (received > 0) {
					headers.Range = 'bytes=' + received + '-';
				}
				const response = await nativeFetch(resourceURLs.get(name), {
					cache: 'no-cache',
					headers: headers,
				});
				if (!response.ok || (response.status !== 200 && response.status !== 206)) {
					throw new Error('HTTP ' + response.status + ' · ' + name);
				}
				if (received > 0) {
					if (response.status === 206) {
						const range = response.headers.get('Content-Range') || '';
						const match = /^bytes (\d+)-(\d+)\/(\d+)$/.exec(range);
						if (!match || Number(match[1]) !== received || Number(match[2]) !== expected - 1 || Number(match[3]) !== expected) {
							throw new Error('服务器返回了错误的断点位置');
						}
					} else {
						chunks.length = 0;
						received = 0;
						retryDetail = ' · 服务器不支持断点续传，正在重新下载';
						updateProgress(received);
					}
				}
				reader = response.body.getReader();
				while (true) {
					const result = await reader.read();
					if (result.done) {
						break;
					}
					if (result.value) {
						chunks.push(result.value);
						received += result.value.byteLength;
						if (received > expected) {
							chunks.length = 0;
							received = 0;
							throw new Error(name + ' 的实际大小超过发布清单');
						}
						retryDetail = '';
						updateProgress(received);
					}
				}
				if (received !== expected) {
					throw new Error(name + ' 下载不完整：' + received + ' / ' + expected + ' 字节');
				}
				return new Blob(chunks, {
					type: name.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream',
				});
			} catch (error) {
				if (reader) {
					try { await reader.cancel(); } catch (_) { /* Already closed. */ }
				}
				if (attempt === maxAttempts) {
					throw new Error(name + ' 下载失败。' + (error.message || String(error)));
				}
				retryDetail = ' · 连接中断，将从 ' + formatMB(received) +
					' MB 继续（第 ' + (attempt + 1) + '/' + maxAttempts + ' 次）';
				updateProgress(received);
				await delay(Math.min(attempt * 750, 3000));
			}
		}
		throw new Error(name + ' 下载失败');
	}

	async function preload(name, cache) {
		if (preloaded.has(name) || await readCached(name, cache)) {
			retryDetail = ' · 已使用完整缓存';
			updateProgress(resourceSize(name));
			return;
		}
		const blob = await download(name);
		if (!await blobMatches(name, blob)) {
			throw new Error(name + ' 的 SHA-256 与本次发布不一致，已阻止新旧资源混用');
		}
		const response = responseFor(name, blob);
		preloaded.set(name, response);
		if (cache) {
			try {
				await cache.put(resourceURLs.get(name), response.clone());
			} catch (_) {
				// The in-memory copy still allows this session to start normally.
			}
		}
	}

	async function ensureEngineScript() {
		if (typeof Engine !== 'undefined') {
			return;
		}
		await new Promise((resolve, reject) => {
			const script = document.createElement('script');
			const url = new URL(publishedName('play.js'), document.baseURI);
			script.src = url.href;
			script.onload = resolve;
			script.onerror = () => reject(new Error('游戏引擎脚本加载失败'));
			document.head.appendChild(script);
		});
	}

	async function cleanOldCaches() {
		if (!('caches' in window)) {
			return;
		}
		try {
			const names = await window.caches.keys();
			await Promise.all(names.filter((name) => name.startsWith(cachePrefix) && name !== cacheName)
				.map((name) => window.caches.delete(name)));
		} catch (_) {
			// Cache cleanup is optional and must not interrupt gameplay.
		}
	}

	async function boot() {
		if (booting) {
			return;
		}
		booting = true;
		completedBytes = 0;
		retryDetail = '';
		showProgress();
		updateProgress(0);
		try {
			await ensureEngineScript();
			const missing = Engine.getMissingFeatures({threads: GODOT_THREADS_ENABLED});
			if (missing.length !== 0) {
				throw new Error('浏览器缺少运行游戏所需的功能：' + missing.join('、'));
			}
			const cache = await openCache();
			for (const name of resourceNames) {
				await preload(name, cache);
				completedBytes += resourceSize(name);
				retryDetail = '';
				updateProgress(0);
			}
			statusDetail.textContent = '资源完整，正在初始化 WebGL；此阶段不会重新下载。' +
				(diagnostic.safeMode ? '稳定模式已降低渲染分辨率并关闭音频。' : '');
			engineAttempted = true;
			engine = new Engine(GODOT_CONFIG);
			await engine.startGame({'onProgress': function () { /* Preloading is already complete. */ }});
			diagnostic.phase = 'running';
			recordBrowserEvent('engine-started', {safeMode: diagnostic.safeMode});
			statusOverlay.remove();
			void cleanOldCaches();
		} catch (error) {
			console.error(error);
			showFailure(error instanceof Error ? error : new Error(String(error)));
		} finally {
			booting = false;
		}
	}

	retryButton.addEventListener('click', function () {
		if (recoveryBlocked) {
			recoveryBlocked = false;
			diagnostic.safeMode = true;
			diagnostic.phase = 'loading';
			recordBrowserEvent('manual-safe-retry');
			void boot();
			return;
		}
		if (engineAttempted) {
			// Godot keeps initialization state outside individual Engine instances.
			// A user-initiated reload is required to reset it; Cache Storage avoids redownloading.
			window.location.reload();
			return;
		}
		void boot();
	});
	function startAfterTabCheck() {
		configureSafeContext();
		if (recoveryBlocked) {
			showRecoveryStop();
		} else {
			void boot();
		}
	}
	void prepareTabSession().then(startAfterTabCheck, startAfterTabCheck);
}());
"""


def patch_html(html: str, version: str, hashes: dict[str, str]) -> str:
    if not re.fullmatch(r"[A-Za-z0-9._-]+", version):
        raise ValueError("Version must contain only letters, digits, dots, underscores, or dashes")
    html = html.replace('<script src="play.js"></script>', f'<script src="play.{version}.js"></script>')
    html = html.replace(
        '<div id="status-notice"></div>',
        '<div id="status-notice"></div>\n\t\t\t<div id="status-detail" role="status" aria-live="polite"></div>\n'
        '\t\t\t<button id="status-retry" type="button" hidden>重试加载</button>',
    )
    html = html.replace("\t\t</style>", LOADER_STYLE + "\t\t</style>", 1)
    html = html.replace("const engine = new Engine(GODOT_CONFIG);", "let engine = null;", 1)
    bootstrap_start = html.index("(function () {", html.index("let engine = null;"))
    bootstrap_end = html.index("}());", bootstrap_start) + len("}());")
    script = "const GAME_VERSION = " + json.dumps(version) + ";\n"
    script += "const GAME_SHA256 = " + json.dumps(hashes, sort_keys=True) + ";\n" + LOADER_SCRIPT
    return html[:bootstrap_start] + script + html[bootstrap_end:]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--index", type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    html = args.input.read_text(encoding="utf-8")
    if args.check:
        required = [
            f'const GAME_VERSION = "{args.version}"',
            f'<script src="play.{args.version}.js"></script>',
            "const GAME_SHA256",
            "new URL(publishedName(name), document.baseURI)",
            "headers.Range",
            "window.caches.open",
            "let engine = null;",
            "engineAttempted = true",
            "BlackholeDiagnostics",
            "recovery-blocked",
            "webglcontextlost",
        ]
        missing = [marker for marker in required if marker not in html]
        if missing:
            raise SystemExit(f"Patched loader is missing markers: {missing}")
        for name in ("play.js", "play.pck", "play.wasm"):
            suffix = name.rsplit(".", 1)[1]
            versioned = args.input.parent / f"play.{args.version}.{suffix}"
            if not versioned.is_file():
                raise SystemExit(f"Versioned runtime file is missing: {versioned}")
        return 0
    hashes = {
        name: hashlib.sha256((args.input.parent / name).read_bytes()).hexdigest()
        for name in ("play.pck", "play.wasm")
    }
    patched = patch_html(html, args.version, hashes)
    args.input.write_text(patched, encoding="utf-8")
    for name in ("play.js", "play.pck", "play.wasm"):
        suffix = name.rsplit(".", 1)[1]
        shutil.copyfile(args.input.parent / name, args.input.parent / f"play.{args.version}.{suffix}")
    if args.index:
        index = args.index.read_text(encoding="utf-8")
        index = index.replace('src="./play.html"', f'src="./play.html?v={args.version}"')
        index = index.replace('href="./play.html"', f'href="./play.html?v={args.version}"')
        args.index.write_text(index, encoding="utf-8")
    print(f"Patched resumable Web loader: {args.input} ({args.version})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
