-- Explicit no-op statement between legacy semicolon-terminated source chunks.
-- Keeps raw parts.txt concatenation valid under LuaJIT as well as Lua 5.4.
do end
