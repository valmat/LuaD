/**
 Internal module for pushing and getting Nullable.
*/

module luad.conversions.nullable;

import std.typecons : Nullable, nullable;
import luad.stack   : pushValue, getValue;
import luad.base    : LuaType;
import luad.c.all;


enum isNullable(T) = is(T == Nullable!U, U);

template NullableType(T)
{
	static if (is(T : Nullable!U, U)) {
		alias NullableType = U;
	} else {
		static assert(0, T.stringof ~ " is not a Nullable.");
	}
}

void pushNullable(T)(lua_State* L, ref T value) if (isNullable!T)
{
	if(value.isNull()) {
		lua_pushnil(L);
		return;
	}
	pushValue(L, value.get());
}

T getNullable(T)(lua_State* L, int idx) if (isNullable!T)
{
	alias SubType = NullableType!T;
	return (LuaType.Nil == lua_type(L, idx)) ?
		T() :
		nullable!SubType(getValue!SubType(L, idx));
}

version(unittest) import luad.testing;
unittest
{
    lua_State* L = luaL_newstate();
    scope(success) lua_close(L);
    luaL_openlibs(L);

    {
        auto v = nullable(42);
        pushValue(L, v);
        assert(popValue!(Nullable!int)(L) == 42);
    }{
        auto v = nullable("42");
        pushValue(L, v);
        assert(popValue!(Nullable!string)(L) == "42");
    }{
        auto v = nullable(X(42));
        pushValue(L, v);
        assert(popValue!(Nullable!X)(L) == X(42));
    }{
        auto v = Nullable!X();
        pushValue(L, v);
        assert(popValue!(Nullable!X)(L).isNull());
    }{
        auto v = Nullable!float();
        pushValue(L, v);
        assert(popValue!(Nullable!float)(L).isNull());
    }{
        5.writeln;
        auto v = nullable("test");
        pushValue(L, v);
        assert(lua_isstring(L, -1));
        assert(getValue!string(L, -1) == "test");
        assert(popValue!(Nullable!string)(L) == "test");
    }{
        auto v = nullable(2.3L);
        pragma(msg,  typeof(v));

        pushValue(L, v);
        assert(lua_isnumber(L, -1));
        lua_setglobal(L, "num");

        unittest_lua(L, `
            assert(num == 2.3)
        `);
    }{
        auto v = nullable(true);
        pushValue(L, v);
        assert(lua_isboolean(L, -1));
        assert(popValue!bool(L));
    }{
        struct S
        {
            int i;
            double n;
            string s;
            void f(){}
        }
        pushValue(L, nullable(S(42, 3.14, "hello")));
        assert(lua_istable(L, -1));
        lua_setglobal(L, "struct");

        unittest_lua(L, `
            for key, expected in pairs{i = 42, n = 3.14, s = "hello"} do
                local value = struct[key]
                assert(
                    value == expected,
                    ("bad table pair: '%s' = '%s' (expected '%s')"):format(key, value, expected)
                )
            end
        `);
    }
}