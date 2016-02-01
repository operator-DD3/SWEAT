#!/usr/bin/env lua

-------------------------------------------------------------------
--  Ceci est une implémentation basique du langage Forth en Lua  --
-------------------------------------------------------------------


--
--  Données
---------------

local stack        = {} -- pile d'exécution
local mem = {}
local rstack = {}
local symbol_table = {} -- table des symboles (fonctions)
local BASE = 10
--
--  Procédures
------------------

local push, pop, dispatch, main_loop

-- pop(n)        --> dépile les n dernières valeurs de la pile `stack`
-- push(a, ...)  --> empile toutes les valeurs passées en paramètre dans `stack`
-- dispatch(...) --> procédure appelée pour dispatcher les symboles lus
-- main_loop()   --> exécute la boucle principale

local make_dispatch_execute_until
local make_dispatch_skip_until

--
--  Implémantation des fonctions de base de Forth
-----------------------------------------------------

symbol_table['+'] = function(...)
  local a, b = pop(2)
  push(a + b)
end

symbol_table['-'] = function(...)
  local a, b = pop(2)
  push(a - b)
end

symbol_table['/'] = function(...)
  local a, b = pop(2)
  push(a / b)
end

symbol_table['*'] = function(...)
  local a, b = pop(2)
  push(a * b)
end

symbol_table['.'] = function(...)
  --print(tostring(pop()) .." ok")
	io.write(tostring(pop() or ""))
	io.flush()
end

symbol_table['EMIT'] = function(...)
	io.write(string.char(pop() or 32))
	io.flush()
end

symbol_table['ROT'] = function(...)
	local c = pop()
	local b = pop()
	local a = pop()
	push(b)
	push(c)
	push(a)
end

symbol_table['<='] = function(...)
  local a, b = pop(2)
  --push(a <= b)
	if a <= b then
		push(1)
	else
		push(0)
	end
end

symbol_table['<'] = function(...)
  local a, b = pop(2)
  --push(a < b)
	if a < b then
		push(1)
	else
		push(0)
	end
end

symbol_table['>='] = function(...)
  local a, b = pop(2)
  --push(a >= b)
	if a >= b then
		push(1)
	else
		push(0)
	end
end

symbol_table['>'] = function(...)
  local a, b = pop(2)
  --push(a > b)
	if a > b then
		push(1)
	else
		push(0)
	end
end

symbol_table['='] = function(...)
	local a, b = pop(2)
	if a==b then
		push(1)
	else
		push(0)
	end
end

symbol_table['MOD'] = function(...)
	local a, b = pop(2)
	push(a % b)
end

symbol_table['.S'] = function(...)
	io.write(#stack,' [')
	for k,v in ipairs(stack) do
		io.write(' ', v)
	end
	io.write(' ]')
end

symbol_table["SWAP"] = function(...)
	a = pop()
	b = pop()
	push(a)
	push(b)
end

symbol_table["OVER"] = function(...)
	a = pop()
	b = pop()
	push(b)
	push(a)
	push(b)
end

symbol_table["AND"] = function(...)
	push(bit.band(pop(), pop()))
end

symbol_table["INVERT"] = function(...)
	push(bit.bnot(pop()))
end

symbol_table["XOR"] = function(...)
	push(bit.bxor(pop(),pop()))
end

symbol_table["OR"] = function(...)
	push(bit.bor(pop(),pop()))
end

-- Comment
symbol_table['('] = function(original_dispatcher)
  return make_dispatch_skip_until(")", original_dispatcher)
end

-- Define new symbol
symbol_table[':'] = function(original_dispatcher)
  local accumulator = {}
  return function(disp, word)
    if word == ";" then
      local sym = table.remove(accumulator, 1)
      symbol_table[sym] = function(disp)
        dispatch_list(original_dispatcher, accumulator)
      end
      return original_dispatcher
    else
      accumulator[#accumulator+1] = word
    end
  end
end

symbol_table["NOP"] = function(...)
end

--symbol_table["BASE"] = function(...)
--	BASE = tonumber(pop())
--end

symbol_table.DUP = function(...)
  local a = pop()
  push(a, a)
end

symbol_table.DROP = function(...)
  pop()
end

symbol_table.CR = function(...)
	io.write('\n')
	io.flush()
end

symbol_table["@"] = function(...)
	local addr = pop()
	local data = mem[addr] or 0
	push(data)
end

symbol_table["!"] = function(...)
	local addr = pop()
	mem[addr] = pop()
end

symbol_table['PAGE'] = function(...)
	--os.execute('clear')
	io.write("\27[2J\27[1;1H")
end

symbol_table['R>'] = function(...)
	rpop()
end

symbol_table['>R'] = function(...)
	rpush()
end

symbol_table['WORDS'] = function(...)
	for k, v in pairs(symbol_table) do
		io.write(k,' ')
	end
	--io.write('\27[1D') --backspace
	io.write('\n')
end

--symbol_table['SEE'] = function(...)
	--print(debug.getinfo(1, "n").name);
	
--end

symbol_table.IF = function(original_dispatcher)
  if pop() ~= 0 then
    return make_dispatch_execute_until(original_dispatcher, "ELSE",
      make_dispatch_skip_until("THEN",
        original_dispatcher))
  else
    return make_dispatch_skip_until("ELSE",
      make_dispatch_execute_until(original_dispatcher, "THEN",
        original_dispatcher))
  end
end

symbol_table["THEN"] = function(...)
end
symbol_table["ELSE"] = function(...)
end

symbol_table['."'] = function(original_dispatcher)
	return make_dispatch_print_until('"',original_dispatcher)
end

symbol_table['BYE'] = function(...)
	os.exit()
end

symbol_table['BL'] = function(...)
	io.write(" ")
end

function sleep(s) local ntime = os.time() + s repeat until os.time() > ntime end
symbol_table['SLEEP'] = function(...)
	sleep(pop())
end

--
--  Dispatch
----------------

-- dispatcher takes:
--   disp: the current dispatcher function
--   word: a string to process
-- it can return a function value which will replace the actual dispatcher.

function dispatch(disp, word)
  -- print(word)

  if symbol_table[word] then      -- Si `word` est dans la table des symboles,
                                  -- appeler la fonction correspondante
    return symbol_table[word](disp)
  elseif symbol_table[string.upper(word)] then
		return symbol_table[string.upper(word)](disp)
  elseif word:match("-?[%d]*.?[%d]*") == word then  -- Si c'est un nombre, empiler `word` Uhmm... in English please?
    --push(tonumber(word,BASE))
		push(tonumber(word))

  else                            -- Sinon, erreur
    io.write("\n\27[31m<<<",word,">>> invalid symbol\27[0m\n")
			errorlevel=1
  end
end

function dispatch_list(disp, list)
  for i = 1, #list do
    local res = disp(disp, list[i])
    if res ~= nil then
      disp = res
    end
  end
end

--
--  Dispatcher Factories
----------------------------

function make_dispatch_execute_until(original_dispatcher, until_word, after_dispatcher)
  return function(disp, word)
    if word == until_word then
      return after_dispatcher
    else
      return original_dispatcher(disp, word)
    end
  end
end

function make_dispatch_skip_until(until_word, after_dispatcher)
  return function(disp, word)
    if word == until_word then
      return after_dispatcher
    end
  end
end

function make_dispatch_print_until(until_word, after_dispatcher)
	local num_printed = 0
  return function(disp, word)
		num_printed = num_printed + 1
    if word == until_word then
			if num_printed > 1 then
			io.write("\27[1D") --backspace over final space
			end
      return after_dispatcher
		else
			io.write(word," ")
    end
  end
end

--
--  Boucle principale
-------------------------

function main_loop()
	print("\27[32mSWEAT V1.16.2.1b\27[0m")
  local input = true
  local disp = dispatch
  while input ~= 'BYE' do
    io.write("> ")
    io.flush()
			errorlevel=0
    --input = string.upper(io.read())
		input = io.read()
    if input then
      local res, msg = pcall(function()
        for word in string.gmatch(input, "%s*(%S+)%s*") do
          local res = disp(disp, word)
          if res ~= nil then
            disp = res
          end
        end
					if errorlevel ~= 1 then
						print(" ok")
					end
      end)
      if not res then
        io.write(msg, "\n")
      end
    end
  end
end

--
--  Fonctions concernant la pile
------------------------------------

function pop(n)
	if #stack > 0 then
  if n == nil or n == 1 then
    return table.remove(stack)
  else
    res = {}
    max = #stack
    for i = 1, n do
      res[i] = stack[max - n + i]
      stack[max - n + i] = nil
    end
    return table.unpack(res)
  end
	else
		print('\27[31mStack Underflow\27[0m')
					errorlevel=1
	end
end

function push(...)
  for i = 1, select("#", ...) do
    stack[#stack+1] = select(i, ...)
  end
end

function rpush()
	rstack[#rstack + 1] = pop()
end

function rpop()
	push(rstack[#rstack])
	rstack[#rstack]=nil
end

--
--  Exécution
-----------------

-- Compatibilité Lua 5.1 / 5.2
if unpack and not table.unpack then
  table.unpack = unpack
end

-- Exécution
main_loop()

