extends Node

signal server_started
signal server_stopped
signal client_connected
signal client_disconnected
signal peer_connected_to_server(id: int)
signal peer_disconnected_from_server(id: int)
signal connection_failed

var peer: WebSocketMultiplayerPeer

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host_game(port: int) -> Error:
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_server(port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		server_started.emit()
		print("[NetworkManager] WebSocket Server started on port ", port)
	else:
		print("[NetworkManager] CRITICAL: Failed to start server on port %d (Error: %d)" % [port, error])
		print("[NetworkManager] This usually means another application is using that port.")
	return error

func join_game(url: String) -> Error:
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client(url)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("[NetworkManager] Connecting to WebSocket: ", url)
	return error

func stop_network():
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	server_stopped.emit()
	print("[NetworkManager] Network stopped")

func _on_peer_connected(id: int):
	print("[NetworkManager] Peer connected: ", id)
	peer_connected_to_server.emit(id)

func _on_peer_disconnected(id: int):
	print("[NetworkManager] Peer disconnected: ", id)
	peer_disconnected_from_server.emit(id)

func _on_connected_to_server():
	print("[NetworkManager] Connected to server successfully")
	client_connected.emit()

func _on_connection_failed():
	print("[NetworkManager] Connection failed")
	connection_failed.emit()

func _on_server_disconnected():
	print("[NetworkManager] Disconnected from server")
	client_disconnected.emit()

