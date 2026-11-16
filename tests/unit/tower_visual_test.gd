extends TestCase


func run() -> void:
	var spawn := SpawnManager.new()
	var tower := spawn.spawn_tower(Vector3(4, 0, 6))
	var visual := tower.model_root as TowerVisual
	visual.build()
	expect(tower.model_id == "final_tower" and visual != null, "终点塔使用独立深蓝三维地标")
	expect_near(tower.footprint_radius, 3.0, 0.0001, "超高视觉不改变三米逻辑占地")
	var top := 0.0
	for child in visual.get_children():
		if child is MeshInstance3D:
			top = maxf(top, child.position.y + child.mesh.get_aabb().size.y * child.scale.y * 0.5)
	expect(top >= TowerVisual.VISUAL_HEIGHT - 0.001 and top > 28.0, "终点塔真实网格高度超过二十八米")
	expect(visual.blue_material.albedo_color.b > visual.blue_material.albedo_color.r * 2.0, "塔身为深蓝色而非金色普通楼")
	expect(visual.glow_material.emission_enabled and visual.glow_material.emission_energy_multiplier > 0.0, "立面和顶灯具有真实发光材质")
	spawn.advance_visuals(0.25, Vector3.ZERO, 0.38)
	expect(is_equal_approx(visual.animation_time, 0.25), "终点塔演出只由固定逻辑步进推进")
	visual.animation_time = 2.0
	var frozen_scale := visual.ground_ring.scale
	visual.animation_time = 2.0
	expect(visual.ground_ring.scale == frozen_scale, "固定动画时间可稳定复现终点塔截图")
	spawn.free()
