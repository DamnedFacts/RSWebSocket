import sys
from twisted.internet import reactor
from twisted.python import log
from autobahn.websocket import WebSocketServerFactory, WebSocketServerProtocol
 
class EchoServerProtocol(WebSocketServerProtocol):
 
   def onMessage(self, msg, binary):
      self.sendMessage(msg, binary)
 
 
class EchoServerFactory(WebSocketServerFactory):
 
   protocol = EchoServerProtocol
 
   def __init__(self, debug):
      self.debug = debug
 
 
if __name__ == '__main__':
 
   log.startLogging(sys.stdout)
   factory = EchoServerFactory(debug = True)
   reactor.listenTCP(9000, factory)
   reactor.run()
