local connection = nil

local host = "localhost"
local username = "root"
local password = ""
local database = "project"

addEventHandler("onResourceStart", resourceRoot , function ()
	connection = dbConnect("mysql", "dbname=" .. database .. ";host=" .. host ..";charset=utf8", username, password, "tag=HesamProject;multi_statements=1")
	if not connection then
		outputServerLog("[MySQL]: Failed to connect the database.")
		outputDebugString("[MySQL]: Failed to connect to database!", 1)
		cancelEvent()
	else
		dbExec(connection, "SET NAMES utf8")
		outputDebugString("[MySQL]: Successful connection to database.")
	end
end,false)

function getConnection()
	return connection
end