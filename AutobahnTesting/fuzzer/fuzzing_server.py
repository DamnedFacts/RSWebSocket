#!/usr/bin/python
#
# fuzzing_server.py
# AutobahnTesting
# 
# Copyright 2012 Richard Emile Sarkis
# Copyright 2011 Tavendo GmbH
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
# 
# http:www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.


import sys
if sys.platform in ['freebsd8']:
   from twisted.internet import kqreactor
   kqreactor.install()

import sys, json
from twisted.python import log
from twisted.internet import reactor
from twisted.web.server import Site
from twisted.web.static import File
from autobahntestsuite.fuzzing import FuzzingServerFactory, FuzzingServerProtocol
from autobahn.websocket import listenWS
from autobahn.websocket import WebSocketProtocol
import autobahntestsuite.case as Case

class RSFuzzingServerProtocol(FuzzingServerProtocol):
    def onOpen(self):
        global lastCaseExpectedClose

        # Call subclass version of onOpen().
        FuzzingServerProtocol.onOpen(self)

        # Set our current state for the runCase we want to run.
        if self.runCase:
            lastCaseExpectedClose = self.runCase.expectedClose
            lastCaseExpectedClose['caseId'] = self.factory.specCases[self.case - 1]
            lastCaseExpectedClose['caseIndex'] = self.case

        # Refer to the case state we just set. The expectation is we are
        # calling this URL immediately after calling runCase().
        if self.path == "/getLastCaseExpectation": 
            if lastCaseExpectedClose:
                self.sendMessage(json.dumps(lastCaseExpectedClose))
            self.sendClose()

        #if self.path == "/getCases":
        #    for k,v in case.CasesById.iteritems():
        #        print k,v
        #    self.sendClose()
    
class RSFuzzingServerFactory(FuzzingServerFactory):
    protocol = RSFuzzingServerProtocol
    """ The rest of the sub-class is inherited """

if __name__ == '__main__':
   lastCaseExpectedClose = None

   log.startLogging(sys.stdout)
   spec = json.loads(open("fuzzing_server_spec.json").read())

   ## fuzzing server
   fuzzer = RSFuzzingServerFactory(spec)
   listenWS(fuzzer)

   #for k,case in Case.CasesById.iteritems():
   #    c = case(fuzzer)
   #    c.onOpen()
   #    print dir(c)

   ## web server
   webdir = File(spec.get("webdir", "."))
   web = Site(webdir)
   reactor.listenTCP(spec.get("webport", 9090), web)

   log.msg("Using Twisted reactor class %s" % str(reactor.__class__))
   reactor.run()
