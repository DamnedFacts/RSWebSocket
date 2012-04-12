/* Source: http://cocoawithlove.com/2008/03/break-into-debugger.html 
   Break into Debugger 
*/
#ifdef DEBUG
    #define DebugBreak() if(AmIBeingDebugged()) {__asm__("int $3\n" : : );}
    bool AmIBeingDebugged(void);
#else
    #define DebugBreak()
#endif