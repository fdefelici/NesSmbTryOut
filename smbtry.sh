ROM_NAME=smbtry
mkdir -p ./bin/$ROM_NAME
./utils/assembler/asm6.exe ./src/$ROM_NAME.S ./bin/$ROM_NAME/$ROM_NAME.nes ./bin/$ROM_NAME/$ROM_NAME.asm
	