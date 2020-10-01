#include <iostream>
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char* argv[]){
	FILE* input;
	input = fopen(argv[1], "rb");
	
	//Handle for console
	HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
	
	for(int next = fgetc(input); next != -1; next = fgetc(input)){
		Sleep(next);
		next = fgetc(input);
		SetConsoleTextAttribute(hConsole, next);
		next = fgetc(input);
		std::cout << (char)next;
	}
}