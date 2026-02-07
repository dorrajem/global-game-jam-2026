class_name TerrainChunk
extends Node

var mesh_instance : MeshInstance3D
var collision_shape : CollisionShape3D
var static_body : StaticBody3D
var objects : Array[Node3D] = []
var chunk_index : int
var z_position : float
