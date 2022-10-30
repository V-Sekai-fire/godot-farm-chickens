extends Node

const quantization_const = preload("quantization.gd")

@export_node_path(RigidBody3D) var rigid_body: NodePath = NodePath("..")
@onready var _rigid_body_node: RigidBody3D = get_node_or_null(rigid_body)

class PhysicsState extends RefCounted:
	const PACKET_LENGTH = 26
	
	var origin: Vector3
	var rotation: Quaternion
	var linear_velocity: Vector3
	var angular_velocity: Vector3
	
	static func encode_physics_state(p_physics_state: PhysicsState) -> PackedByteArray:
		assert(p_physics_state)
		
		var buf: PackedByteArray = PackedByteArray()
		assert(buf.resize(PACKET_LENGTH) == OK)
			
		buf.encode_half(0, p_physics_state.origin.x)
		buf.encode_half(2, p_physics_state.origin.y)
		buf.encode_half(4, p_physics_state.origin.z)
		
		var quat: Quaternion = p_physics_state.rotation
		buf.encode_half(6, quat.x)
		buf.encode_half(8, quat.y)
		buf.encode_half(10, quat.z)
		buf.encode_half(12, quat.w)
		
		buf.encode_half(14, p_physics_state.linear_velocity.x)
		buf.encode_half(16, p_physics_state.linear_velocity.y)
		buf.encode_half(18, p_physics_state.linear_velocity.z)
		
		buf.encode_half(20, p_physics_state.angular_velocity.x)
		buf.encode_half(22, p_physics_state.angular_velocity.y)
		buf.encode_half(24, p_physics_state.angular_velocity.z)
		
		return buf
		
	static func decode_physics_state(p_physics_byte_array: PackedByteArray) -> PhysicsState:
		var new_physics_state: PhysicsState = PhysicsState.new()
		
		if p_physics_byte_array.size() == PACKET_LENGTH:
			var new_origin: Vector3 = Vector3()
			new_origin.x = p_physics_byte_array.decode_half(0)
			new_origin.y = p_physics_byte_array.decode_half(2)
			new_origin.z = p_physics_byte_array.decode_half(4)
			
			var new_rotation: Quaternion = Quaternion()
			new_rotation.x = p_physics_byte_array.decode_half(6)
			new_rotation.y = p_physics_byte_array.decode_half(8)
			new_rotation.z = p_physics_byte_array.decode_half(10)
			new_rotation.w = p_physics_byte_array.decode_half(12)
			
			var new_linear_velocity: Vector3 = Vector3()
			new_linear_velocity.x = p_physics_byte_array.decode_half(14)
			new_linear_velocity.y = p_physics_byte_array.decode_half(16)
			new_linear_velocity.z = p_physics_byte_array.decode_half(18)
			
			var new_angular_velocity: Vector3 = Vector3()
			new_angular_velocity.x = p_physics_byte_array.decode_half(20)
			new_angular_velocity.y = p_physics_byte_array.decode_half(22)
			new_angular_velocity.z = p_physics_byte_array.decode_half(24)
			
			new_physics_state.origin = new_origin
			new_physics_state.rotation = new_rotation
			new_physics_state.linear_velocity = new_linear_velocity
			new_physics_state.angular_velocity = new_angular_velocity

		return new_physics_state
	
	func set_from_rigid_body(p_rigid_body: RigidBody3D):
		origin = p_rigid_body.transform.origin
		rotation = p_rigid_body.transform.basis.get_rotation_quaternion()
		linear_velocity = p_rigid_body.linear_velocity
		angular_velocity = p_rigid_body.angular_velocity

@export var sync_net_state : PackedByteArray:
	get:
		if _rigid_body_node:
			var physics_state: PhysicsState = PhysicsState.new()
			physics_state.set_from_rigid_body(_rigid_body_node)
			
			return PhysicsState.encode_physics_state(physics_state)
			
		return PackedByteArray()
		
	set(value):
		if typeof(value) != TYPE_PACKED_BYTE_ARRAY:
			return
		if value.size() != PhysicsState.PACKET_LENGTH:
			return
		
		if _rigid_body_node:
			if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority() and not _rigid_body_node.pending_authority_request:
				var physics_state: PhysicsState = PhysicsState.decode_physics_state(value)
				
				_rigid_body_node.transform = Transform3D(Basis(physics_state.rotation), physics_state.origin)
				_rigid_body_node.linear_velocity = physics_state.linear_velocity
				_rigid_body_node.angular_velocity = physics_state.angular_velocity
				
