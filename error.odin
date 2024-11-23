package main

error :: struct
{
	Message : string,
	LineNumber : int,
}

gErrors : [dynamic]error

ReportError :: proc(LineNumber : int, Message : string)
{
	Error := error{Message, LineNumber}

	append(&gErrors, Error)
}

