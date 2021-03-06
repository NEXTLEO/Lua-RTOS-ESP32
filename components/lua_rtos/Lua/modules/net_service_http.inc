/*
 * Lua RTOS, lua http module
 *
 * Copyright (C) 2015 - 2017
 * IBEROXARXA SERVICIOS INTEGRALES, S.L. & CSS IBÉRICA, S.L.
 *
 * Author: Jaume Olivé (jolive@iberoxarxa.com / jolive@whitecatboard.org)
 *
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software
 * and its documentation for any purpose and without fee is hereby
 * granted, provided that the above copyright notice appear in all
 * copies and that both that the copyright notice and this
 * permission notice and warranty disclaimer appear in supporting
 * documentation, and that the name of the author not be used in
 * advertising or publicity pertaining to distribution of the
 * software without specific, written prior permission.
 *
 * The author disclaim all warranties with regard to this
 * software, including all implied warranties of merchantability
 * and fitness.  In no event shall the author be liable for any
 * special, indirect or consequential damages or any damages
 * whatsoever resulting from loss of use, data or profits, whether
 * in an action of contract, negligence or other tortious action,
 * arising out of or in connection with the use or performance of
 * this software.
 */

#include "sdkconfig.h"

#if CONFIG_LUA_RTOS_USE_HTTP_SERVER

#include "net.h"

#include "lwip/err.h"

#include <drivers/net.h>

extern int http_start(lua_State* L);
extern void http_stop();
extern int http_print(lua_State* L);

static int lhttp_start(lua_State* L) {
	return http_start(L);
}

static int lhttp_stop(lua_State* L) {
	http_stop();
	return 0;
}

static int lhttp_print(lua_State* L) {
	return http_print(L);
}

static const LUA_REG_TYPE http_map[] = {
    { LSTRKEY( "start" ),	 LFUNCVAL( lhttp_start   ) },
    { LSTRKEY( "stop"  ),	 LFUNCVAL( lhttp_stop    ) },
    { LSTRKEY( "print_chunk"  ),	 LFUNCVAL( lhttp_print    ) },
	{ LNILKEY, LNILVAL }
};

#endif
