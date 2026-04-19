## SignalBus.gd
## Global event relay autoload. Components emit signals here; systems listen here.
## Never holds state — pure communication channel.
## RPC emitters are used for signals that must fire on all peers.
extends Node
