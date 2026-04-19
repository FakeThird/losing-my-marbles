extends Node

signal marble_launched
signal marble_stopped
signal marble_ejected(count: int)
signal marble_hit
	
var active_marble: RigidBody2D = null
var ejected_count: int = 0

func set_active_marble(marble: RigidBody2D):
	active_marble = marble

func on_marble_launched():
	marble_launched.emit()

func on_marble_stopped():
	marble_stopped.emit()

func on_marble_ejected():
	ejected_count += 1
	marble_ejected.emit(ejected_count)

func reset_ejected():
	ejected_count = 0
	
func on_marble_hit():
	marble_hit.emit()
