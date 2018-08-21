local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Util = require(script.Parent.Util)
local Command = require(script.Parent.Command)

--- The dispatcher handles creating and running commands during the game.
local Dispatcher = {
	Cmdr = nil;
	Registry = nil;
}

--- Takes in raw command information and generates a command out of it.
-- text and executor are required arguments.
-- allowIncompleteData, when true, will ignore errors about arguments missing so we can parse live as the user types.
-- data is for speccial networked data about the command gathered on the client. Purely optional.
-- returns the command if successful, or (false, errorText) if not
function Dispatcher:Evaluate (text, executor, allowIncompleteArguments, data)
	if RunService:IsClient() == true and executor ~= game.Players.LocalPlayer then
		error("Can't evaluate a command that isn't sent by the local player.")
	end

	local arguments = Util.SplitString(text)
	local commandName = table.remove(arguments, 1)
	local commandObject = self.Registry:GetCommand(commandName)

	if commandObject then
		-- No need to continue splitting when there are no more arguments. We'll just mash any additional arguments into the last one.
		arguments = Util.MashExcessArguments(arguments, #commandObject.args)

		-- Create the CommandContext and parse it.
		local command = Command.new(self, text, commandObject, executor, arguments, data)
		local success, errorText = command:Parse(allowIncompleteArguments)

		if success then
			return command
		else
			return false, errorText
		end
	else
		return false, "Invalid command. Use the help command to see all available commands."
	end
end

--- A helper that evaluates and runs the command in one go.
-- Either returns any validation errors as a string, or the output of the command as a string. Definitely a string, though.
function Dispatcher:EvaluateAndRun (text, executor, data)
	executor = executor or Players.LocalPlayer

	local command, errorText = self:Evaluate(text, executor, data)

	if not command then
		return errorText
	end

	local valid, errorText = command:Validate()

	if not valid then
		return errorText
	end

	return command:Run() or "Command executed."
end

--- Send text as the local user to remote server to be evaluated there.
function Dispatcher:Send (text, data)
	if RunService:IsClient() == false then
		error("Dispatcher::Send can only be called from the client.")
	end

	return self.Cmdr.RemoteFunction:InvokeServer(text, data)
end

--- Invoke a command programmatically as the local user e.g. from a settings menu
-- Command should be the first argument, all arguments afterwards should be the arguments to the command.
function Dispatcher:Run (...)
	local args = {...}
	local text = args[1]

	for i = 2, #args do
		text = text .." " .. tostring(args[i])
	end

	local command, errorText = self:Evaluate(text, game.Players.LocalPlayer)

	if not command then
		error(errorText) -- We do a full-on error here since this is code-invoked and they should know better.
	end

	local success, errorText = command:Validate()

	if not success then
		error(errorText)
	end

	return command:Run()
end

return function (cmdr)
	Dispatcher.Cmdr = cmdr
	Dispatcher.Registry = cmdr.Registry

	return Dispatcher
end