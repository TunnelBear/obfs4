set GOARCH=386
go build -o x86/obfs4proxy.exe
set GOARCH=amd64
go build -o x64/obfs4proxy.exe