#include <iostream>
#include <math.h>
#include <fstream>
#include <string>
#include <array>
#include <vector>
#include <iterator>
#include <cmath>
#include "CIEDE2000.h"
#include "bitmap_image.hpp"
#include <windows.h>

#define printableChars 95
#define startingChar 32

/** A color in CIELAB colorspace */
	struct LAB
	{
		/** Lightness */
		float l;
		/** Color-opponent a dimension */
		float a;
		/** Color-opponent b dimension */
		float b;
	};
	/** Convenience definition for struct LAB */
	using LAB = struct LAB;

/** 
 * @brief Inverse sRGB gamma correction, transforms R' to R 
 */
#define INVGAMMACORRECTION(t)	\
	(((t) <= 0.0404482362771076) ? \
	((t)/12.92) : pow(((t) + 0.055)/1.055, 2.4))

/** @brief XYZ color of the D65 white point */
#define WHITEPOINT_X	0.950456
#define WHITEPOINT_Y	1.0
#define WHITEPOINT_Z	1.088754

/** 
 * @brief CIE L*a*b* f function (used to convert XYZ to L*a*b*)
 * http://en.wikipedia.org/wiki/Lab_color_space
 */
#define LABF(t)	\
	((t >= 8.85645167903563082e-3) ? \
	pow(t,0.333333333333333) : (841.0/108.0)*(t) + (4.0/29.0))

//Convert rgb to lab
LAB rgb2lab(float R, float G, float B){
	
	//rgb 2 xyz
	R /= 255.0;
	G /= 255.0;
	B /= 255.0;
	
	R = INVGAMMACORRECTION(R);
	G = INVGAMMACORRECTION(G);
	B = INVGAMMACORRECTION(B);
	float X = (0.4123955889674142161*R + 0.3575834307637148171*G + 0.1804926473817015735*B);
	float Y = (0.2125862307855955516*R + 0.7151703037034108499*G + 0.07220049864333622685*B);
	float Z = (0.01929721549174694484*R + 0.1191838645808485318*G + 0.9504971251315797660*B);
	
	//XYZ 2 Lab
	X /= WHITEPOINT_X;
	Y /= WHITEPOINT_Y;
	Z /= WHITEPOINT_Z;
	X = LABF(X);
	Y = LABF(Y);
	Z = LABF(Z);
	float L = 116*Y - 16;
	float a = 500*(X - Y);
	float b = 200*(Y - Z);
	
	return {L, a, b};
}

//Represents a printable character and its colour
struct printable{
	int character;
	int consoleColour;
	LAB colour;
};
using Printable = struct printable;

//Convert a pixel
__global__
void convert(Printable *output, Printable* printables, LAB* image, int offset, int total){
	int index = blockDim.x * blockIdx.x + threadIdx.x + offset;//Get pixel index to process
	
	if(index > total)
		return;
	
	LAB lab1 = image[index];//Get colour value
	float minDiff = 500;//Set high min diff
	int minDiffIndex = 0;//Index of closest character
	for(int i = 0; i < (printableChars * 256); i++){//For everything printable to console
		
		LAB lab2 = printables[i].colour;//Colour of current char/colour combo
		
		//Big fat CIEDE2000 comparison (super slow gpu killer)
		
		// 
		// "For these and all other numerical/graphical 􏰀delta E00 values
		// reported in this article, we set the parametric weighting factors
		// to unity(i.e., k_L = k_C = k_H = 1.0)." (Page 27).
		 
		const float k_L = 1.0, k_C = 1.0, k_H = 1.0;
		const float deg360InRad = 6.283185307179586476925286766559;
		const float deg180InRad = 3.1415926535897932384626433832795;
		const float pow25To7 = 6103515625.0; // pow(25, 7) 
		
		//
		// Step 1 
		 
		// Equation 2 
		float C1 = sqrt((lab1.a * lab1.a) + (lab1.b * lab1.b));
		float C2 = sqrt((lab2.a * lab2.a) + (lab2.b * lab2.b));
		// Equation 3 
		float barC = (C1 + C2) / 2.0f;
		// Equation 4 
		float powbarc7 = barC * barC * barC * barC * barC * barC * barC;
		float G = 0.5f * (1 - sqrt(powbarc7 / (powbarc7 + pow25To7)));
		// Equation 5 
		float a1Prime = (1.0f + G) * lab1.a;
		float a2Prime = (1.0f + G) * lab2.a;
		// Equation 6 
		float CPrime1 = sqrt((a1Prime * a1Prime) + (lab1.b * lab1.b));
		float CPrime2 = sqrt((a2Prime * a2Prime) + (lab2.b * lab2.b));
		// Equation 7 
		float hPrime1;
		if (lab1.b == 0 && a1Prime == 0)
			hPrime1 = 0.0f;
		else {
			hPrime1 = atan2(lab1.b, a1Prime);
			// 
			// This must be converted to a hue angle in degrees between 0 
			// and 360 by addition of 2􏰏 to negative hue angles.
			 
			if (hPrime1 < 0)
				hPrime1 += deg360InRad;
		}
		float hPrime2;
		if (lab2.b == 0 && a2Prime == 0)
			hPrime2 = 0.0f;
		else {
			hPrime2 = atan2(lab2.b, a2Prime);
			// 
			// This must be converted to a hue angle in degrees between 0 
			// and 360 by addition of 2􏰏 to negative hue angles.
			 
			if (hPrime2 < 0)
				hPrime2 += deg360InRad;
		}
		
		//
		// Step 2
		 
		// Equation 8 
		float deltaLPrime = lab2.l - lab1.l;
		// Equation 9 
		float deltaCPrime = CPrime2 - CPrime1;
		// Equation 10 
		float deltahPrime;
		float CPrimeProduct = CPrime1 * CPrime2;
		if (CPrimeProduct == 0)
			deltahPrime = 0;
		else {
			// Avoid the fabs() call 
			deltahPrime = hPrime2 - hPrime1;
			if (deltahPrime < -deg180InRad)
				deltahPrime += deg360InRad;
			else if (deltahPrime > deg180InRad)
				deltahPrime -= deg360InRad;
		}
		// Equation 11 
		float deltaHPrime = 2.0f * sqrt(CPrimeProduct) *
			sin(deltahPrime / 2.0f);
		
		//
		// Step 3
		 
		// Equation 12 
		float barLPrime = (lab1.l + lab2.l) / 2.0f;
		// Equation 13 
		float barCPrime = (CPrime1 + CPrime2) / 2.0f;
		// Equation 14 
		float barhPrime, hPrimeSum = hPrime1 + hPrime2;
		if (CPrime1 * CPrime2 == 0) {
			barhPrime = hPrimeSum;
		} else {
			if (fabs(hPrime1 - hPrime2) <= deg180InRad)
				barhPrime = hPrimeSum / 2.0f;
			else {
				if (hPrimeSum < deg360InRad)
					barhPrime = (hPrimeSum + deg360InRad) / 2.0f;
				else
					barhPrime = (hPrimeSum - deg360InRad) / 2.0f;
			}
		}
		// Equation 15 
		float T = 1.0 - (0.17f * cos(barhPrime - 0.5235987756f)) +
			(0.24f * cos(2.0f * barhPrime)) +
			(0.32f * cos((3.0f * barhPrime) + 0.10471975512f )) - 
			(0.20f * cos((4.0f * barhPrime) - 1.0995574288f));
		// Equation 16 
		float deltaTheta = 0.5235987756f *
			exp(-(((barhPrime - 4.799655443f) / 0.436332313f) * ((barhPrime - 4.799655443f) / 0.436332313f)));
		// Equation 17 
		float temp17_1 = (barCPrime * barCPrime * barCPrime * barCPrime * barCPrime * barCPrime * barCPrime);
		float R_C = 2.0f * sqrt(temp17_1 /
			(temp17_1 + pow25To7));
		// Equation 18 
		float temp18_1 = ((barLPrime - 50.0f) * (barLPrime - 50));
		float S_L = 1 + ((0.015f * temp18_1) /
			sqrt(20 + temp18_1));
		// Equation 19 
		float S_C = 1 + (0.045f * barCPrime);
		// Equation 20 
		float S_H = 1 + (0.015f * barCPrime * T);
		// Equation 21 
		float R_T = (-sin(2.0f * deltaTheta)) * R_C;
		
		float asdf1 = (deltaLPrime / (k_L * S_L));
		float asdf2 = (deltaCPrime / (k_C * S_C));
		float asdf3 = (deltaHPrime / (k_H * S_H));
		// Equation 22
		float deltaE = sqrt(
			(asdf1 * asdf1) +
			(asdf2 * asdf2) +
			(asdf3 * asdf3) + 
			(R_T * (deltaCPrime / (k_C * S_C)) * (deltaHPrime / (k_H * S_H))));
		
		if(deltaE < minDiff){
			minDiff = deltaE;
			minDiffIndex = i;
		}
	}
	output[index] = printables[minDiffIndex];
}

int main(int argc, char *argv[])
{
	//Load charset image
	bitmap_image charsetImg("charset.bmp");
	//Initialize array for every printable character in every colour in VRAM
	Printable *printables;
	cudaMallocManaged(&printables, printableChars * 256 * sizeof(Printable));
	
	//Handle for console
	HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
	
	for(int col = 0; col < 256; col++){//For every colour
		for(int c = 0; c < printableChars; c++){//And every character
			int rTotal = 0;
			int gTotal = 0;
			int bTotal = 0;
			for(int x = 0; x < 8; x++){//For every pixel in the character
				for(int y = 0; y < 8; y++){
					rgb_t colour;
					charsetImg.get_pixel((c + startingChar) * 8 + x, col * 8 + y, colour);//Get colour of pixel at that location on the character
					rTotal += colour.red;//Add to totals
					gTotal += colour.green;
					bTotal += colour.blue;
					
				}
			}
			/*SetConsoleTextAttribute(hConsole, (char)col);
			std::cout << chars[c];
			SetConsoleTextAttribute(hConsole, 15);
			*/
			LAB avgColour = rgb2lab((double)(rTotal / 64), (double)(gTotal / 64), (double)(bTotal / 64));//Convert average rgb into lab
			//std::cout << ": " << avgColour.l << " " << avgColour.a << " " << avgColour.b << std::endl;
			printables[c + printableChars * col] = {c + startingChar, col, avgColour};//Set character in printables
		}
	}
	std::cout << "Characters coloured" << std::endl;
	
	bitmap_image testImg(argv[1]);//Load image
	
	int width = testImg.width();//Get dimensions
	int height = testImg.height();
	
	int pixels = width * height;//Number of pixels in image
	
	//Allocate result array
	Printable *result;
	cudaMallocManaged(&result, pixels * sizeof(Printable));
	
	//Array for pixel colour values in vram
	LAB* image;
	cudaMallocManaged(&image, pixels * sizeof(LAB));
	
	//For every pixel
	for(int x = 0; x < width; x++){
		for(int y = 0; y < height; y++){
			rgb_t colour;
			testImg.get_pixel(x, y, colour);//Get the colour
			image[(y * width) + x] = rgb2lab(colour.red, colour.green, colour.blue);//Convert it to LAB and store in array
		}
	}
	int pixelsLeft = pixels;//Number of pixels yet to process
	while(pixelsLeft > 0){//While there are pixels to process
		int pixelsToDo;//Pixels to process in this round
		if(pixelsLeft < 4096)//Process 5000 unless we are near the end, then process the rest
			pixelsToDo = pixelsLeft;
		else
			pixelsToDo = 4096;
		
		std::cout << "Running " << pixelsToDo << " pixels from " << pixels - pixelsLeft << std::endl;
		
		int blockSize = 64;//1024 threads per block
		int numBlocks = (pixelsToDo + blockSize - 1) / blockSize;//However many blocks we need
		
		// Run kernel
		convert<<<numBlocks, blockSize>>>(result, printables, image, pixels - pixelsLeft, pixels);
		
		cudaDeviceSynchronize();//Wait for kernels to finish
		pixelsLeft -= pixelsToDo;//Less pixels left
	}
	
	//bitmap_image outputImage(width * 8, height * 8);
	FILE* bm = fopen(argv[2], "wb");
	fputc('B', bm);
	fputc('M', bm);
	int size = 54 + (((int)((192.0f * width + 31.0f) / 32)) * 4) * height * 8;
	int padding = (((int)((192.0f * width + 31.0f) / 32)) * 4) - (width * 24);
	fputc(size & 0xff, bm);
	fputc((size & 0xff00) >> 8, bm);
	fputc((size & 0xff0000) >> 16, bm);
	fputc((size & 0xff000000) >> 24, bm);
	fwrite("\0\0\0\006\0\0\0", 1, 8, bm);
	fwrite("(\0\0\0", 1, 4, bm);
	fputc(width * 8 & 0xff, bm);
	fputc((width * 8 & 0xff00) >> 8, bm);
	fputc((width * 8 & 0xff0000) >> 16, bm);
	fputc((width * 8 & 0xff000000) >> 24, bm);
	fputc(height * 8 & 0xff, bm);
	fputc((height * 8 & 0xff00) >> 8, bm);
	fputc((height * 8 & 0xff0000) >> 16, bm);
	fputc((height * 8 & 0xff000000) >> 24, bm);
	fputc(1, bm);
	fputc(0, bm);
	fputc(24, bm);
	fputc(0, bm);
	fwrite("\0\0\0\0\0\0\0\00d\0\0\00d\0\0\0\0\0\0\0\0\0\0\0", 1, 24, bm);
	FILE* sauce;
	if(argc > 3){
		sauce = fopen(argv[3], "wb");
	}
	for(int y = height - 1; y >= 0; y--){//For every pixel
		//Bitmap
		for(int subY = 0; subY < 8; subY++){
			for(int x = 0; x < width; x++){
				int colour = result[x + (y * width)].consoleColour;//Get colour
				int character = result[x + (y * width)].character;//Get character
				for(int subX = 0; subX < 8; subX++){
					rgb_t color;
					charsetImg.get_pixel(character * 8 + subX, colour * 8 + 7 - subY, color);
					fputc(color.blue, bm);
					fputc(color.green, bm);
					fputc(color.red, bm);
				}
			}
			for(int i = 0; i < padding; i++){
				fputc('\0', bm);
			}
		}
	}
	fclose(bm);
	for(int y = 0; y < height; y++){//For every pixel
		for(int x = 0; x < width; x++){
			int colour = result[x + (y * width)].consoleColour;//Get colour
			int character = result[x + (y * width)].character;//Get character
			
			if(character == 0 || character == 7 || character == 8 || character == 9 || character == 10 || character == 13){
				character = 0x20;
			}
			
			SetConsoleTextAttribute(hConsole, colour);//Set colour
			std::cout << (char)character;//Print character
			
			//Bitmap output
			//bitmap_image characterImage(8, 8);
			//charsetImg.region((character - startingChar) * 8, colour * 8, 8, 8, characterImage);
			//outputImage.copy_from(characterImage, x * 8, y * 8);
			
			
			//Special sauce output
			if(argc > 3){
				fputc(1, sauce);
				fputc(colour, sauce);
				fputc(character, sauce);
			}
		}
		SetConsoleTextAttribute(hConsole, 15);//Set colour back to default(line break changing bg colour is really slow)
		std::cout << std::endl;//New line
		if(argc > 3){
			fputc(1, sauce);
			fputc(15, sauce);
			fputc(10, sauce);
		}
	}
	//outputImage.save_image(argv[2]);
	
	if(argc > 3)
		fclose(sauce);

	return 0;
}