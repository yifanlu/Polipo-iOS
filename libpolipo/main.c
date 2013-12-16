/*
Copyright (c) 2003-2006 by Juliusz Chroboczek

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include "polipo.h"

AtomPtr configFile = NULL;
int daemonise = 0;
int maxIdleMilliseconds = -1;
FILE *logF = NULL;
#ifdef HAVE_FORK
volatile sig_atomic_t exitFlag;
#else
int exitFlag;
#endif
static FdEventHandlerPtr listener = NULL;

int
polipoInit(const char *config)
{
    int rc;
    
    initAtoms();
    CONFIG_VARIABLE(maxIdleMilliseconds, CONFIG_INT, "Max idle time (in milliseconds) in event loop before returning. -1 means infinite.");
    
    preinitChunks();
    preinitLog();
    preinitObject();
    preinitIo();
    preinitDns();
    preinitServer();
    preinitHttp();
    preinitDiskcache();
    preinitLocal();
    preinitForbidden();
    preinitSocks();
    
    if (config != NULL && access(config, F_OK) == 0)
    {
        configFile = internAtom(config);
    }
    
    rc = parseConfigFile(configFile);
    if(rc < 0)
        return -1;
    
    initChunks();
    initLog();
    initObject();
    initEvents();
    initIo();
    initDns();
    initHttp();
    initServer();
    initDiskcache();
    initForbidden();
    initSocks();
    
    return 0;
}

int
polipoListenInit()
{
    exitFlag = 0;
    listener = create_listener(proxyAddress->string,
                               proxyPort, httpAccept, NULL);
    if(!listener) {
        return -1;
    }
    else {
        return 0;
    }
}

void
polipoSetLog(FILE *file)
{
    logF = file;
}

int
polipoGetListenerSocket()
{
    return listener ? listener->fd : -1;
}

int
polipoDoEvents()
{
    return doEvents();
}

int
polipoClearCache()
{
    expireDiskObjects();
    return 0;
}

void
polipoExit()
{
    exitFlag = 3;
}

void
polipoRelease()
{
    
}
