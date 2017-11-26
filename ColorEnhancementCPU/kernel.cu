/*
* Copyright 1993-2013 NVIDIA Corporation.  All rights reserved.
*
* Please refer to the NVIDIA end user license agreement (EULA) associated
* with this source code for terms and conditions that govern your use of
* this software. Any use, reproduction, disclosure, or distribution of
* this software and related documentation outside the terms of the EULA
* is strictly prohibited.
*
*/

// This example implements the contrast adjustment on an 8u one-channel image by using
// Nvidia Performance Primitives (NPP). 
// Assume pSrc(i,j) is the pixel value of the input image, nMin and nMax are the minimal and 
// maximal values of the input image. The adjusted image pDst(i,j) is computed via the formula:
// pDst(i,j) = (pSrc(i,j) - nMin) / (nMax - nMin) * 255 
//
// The code flow includes five steps:
// 1) Load the input image into the host array;
// 2) Allocate the memory space on the GPU and copy data from the host to GPU;
// 3) Call NPP functions to adjust the contrast;
// 4) Read data back from GPU to the host;
// 5) Output the result image and clean up the memory.

#include <iostream>
#include <fstream>
#include <sstream>
#include "npp.h"
#include <windows.h>

double PCFreq = 0.0;
__int64 CounterStart = 0;

void StartCounter()
{
	LARGE_INTEGER li;
	if (!QueryPerformanceFrequency(&li))
		std::cout << "QueryPerformanceFrequency failed!\n";

	PCFreq = double(li.QuadPart) / 1000000.0;

	QueryPerformanceCounter(&li);
	CounterStart = li.QuadPart;
}
double GetCounter()
{
	LARGE_INTEGER li;
	QueryPerformanceCounter(&li);
	return double(li.QuadPart - CounterStart) / PCFreq;
}

struct MinMax {
	Npp8u min;
	Npp8u max;
};
// Function declarations.
Npp8u *
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray);

void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray);

MinMax 
MinMaxCalc( Npp8u * pSrc_Host, int & nWidth, int & nHeight);

void
SubtractMin(Npp8u * pDst_Host, Npp8u  nMin, Npp8u * pSrc_Host, int & nWidth, int & nHeight);

void 
MultiplyConstantDivideScaleFactor(Npp8u * pDst_Host, Npp8u  nConstant, int nScaleFactor, int & nWidth, int & nHeight);

// Main function.
int
main(int argc, char ** argv)
{
	// Host parameter declarations.	
	Npp8u * pSrc_Host, *pDst_Host;
	int   nWidth, nHeight, nMaxGray;

	// Load image to the host.
	std::cout << "Load PGM file." << std::endl;
	pSrc_Host = LoadPGM((char *)"C:\\Users\\blgnksy\\source\\repos\\CudaAssignment2\\ColorEnhancement\\lena_before.pgm", nWidth, nHeight, nMaxGray);
	pDst_Host = new Npp8u[nWidth * nHeight];

	std::cout << "Process the image on CPU." << std::endl;
	StartCounter();

	/*CPU Min Max Calculator*/
	MinMax mm=MinMaxCalc(pSrc_Host, nWidth, nHeight);
	printf("%d\t%d\n", mm.min, mm.max);
	int nScaleFactor = 0;
	int nPower = 1;
	while (nPower * 255.0f / (mm.max - mm.min) < 255.0f)
	{
		nScaleFactor++;
		nPower *= 2;
	}

	Npp8u nConstant = static_cast<Npp8u>(255.0f / (mm.max - mm.min) * (nPower / 2));
	printf("Constant is %d.\n", nConstant);

	SubtractMin(pDst_Host, mm.min, pSrc_Host, nWidth, nHeight);

	MultiplyConstantDivideScaleFactor(pDst_Host, nConstant, nScaleFactor,  nWidth, nHeight);

	std::cout<<GetCounter()<<" ms."<<std::endl;
	std::cout << "Work done!" << std::endl;

	// Output the result image.
	std::cout << "Output the PGM file." << std::endl;
	WritePGM((char *)"C:\\Users\\blgnksy\\source\\repos\\CudaAssignment2\\lena_afterCPU3.pgm", pDst_Host, nWidth, nHeight, nMaxGray);

	// Clean up.
	std::cout << "Clean up." << std::endl;
	delete[] pSrc_Host;
	delete[] pDst_Host;


	getchar();
	return 0;
}

// Disable reporting warnings on functions that were marked with deprecated.
#pragma warning( disable : 4996 )

// Load PGM file.
Npp8u *
LoadPGM(char * sFileName, int & nWidth, int & nHeight, int & nMaxGray)
{
	char aLine[256];
	FILE * fInput = fopen(sFileName, "r");
	if (fInput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	// First line: version
	fgets(aLine, 256, fInput);
	std::cout << "\tVersion: " << aLine;
	// Second line: comment
	fgets(aLine, 256, fInput);
	std::cout << "\tComment: " << aLine;
	fseek(fInput, -1, SEEK_CUR);
	// Third line: size
	fscanf(fInput, "%d", &nWidth);
	std::cout << "\tWidth: " << nWidth;
	fscanf(fInput, "%d", &nHeight);
	std::cout << " Height: " << nHeight << std::endl;
	// Fourth line: max value
	fscanf(fInput, "%d", &nMaxGray);
	std::cout << "\tMax value: " << nMaxGray << std::endl;
	while (getc(fInput) != '\n');
	// Following lines: data
	Npp8u * pSrc_Host = new Npp8u[nWidth * nHeight];
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			pSrc_Host[i*nWidth + j] = fgetc(fInput);
	fclose(fInput);

	return pSrc_Host;
}

// Write PGM image.
void
WritePGM(char * sFileName, Npp8u * pDst_Host, int nWidth, int nHeight, int nMaxGray)
{
	FILE * fOutput = fopen(sFileName, "w+");
	if (fOutput == 0)
	{
		perror("Cannot open file to read");
		exit(EXIT_FAILURE);
	}
	char * aComment = (char *)"# Created by Bilgin Aksoy CUDA Assignment";
	fprintf(fOutput, "P5\n%s\n%d %d\n%d\n", aComment, nWidth, nHeight, nMaxGray);
	for (int i = 0; i < nHeight; ++i)
		for (int j = 0; j < nWidth; ++j)
			fputc(pDst_Host[i*nWidth + j], fOutput);
	fclose(fOutput);
}

MinMax 
MinMaxCalc( Npp8u * pSrc_Host, int & nWidth, int & nHeight) {
	Npp8u min = 0;
	Npp8u max = 0;
	for (int i = 0; i < nHeight; i++)
	{
		for (int j = 0; j < nWidth; j++)
		{
			if (i ==0 && j == 0)
			{
				min = pSrc_Host[i*nWidth + j];
			}
			if (pSrc_Host[i*nWidth + j] <= min)
			{
				min = pSrc_Host[i*nWidth + j];
			}
			if (pSrc_Host[i*nWidth + j] >= max)
			{
				max = pSrc_Host[i*nWidth + j];
			}
		}
	}

	MinMax mm = { min,max };
	printf("Min Value= %d Max Value=%d for the given image.\n", mm.min, mm.max);
	//getchar();
	return mm;
}

void SubtractMin(Npp8u * pDst_Host, Npp8u   nMin, Npp8u * pSrc_Host, int & nWidth, int & nHeight) {
	for (int i = 0; i < nHeight; i++)
	{
		for (int j = 0; j < nWidth; j++)
		{
			//printf("Before subtract %d\n", pDst_Host[i*nWidth + j]);
			pDst_Host[i*nWidth + j] = pSrc_Host[i*nWidth + j] - nMin;
			//printf("After subtract %d\n", pDst_Host[i*nWidth + j]);
		}
	}
	//printf("Mininum Value Subtracted...\n");
	//getchar();
}

void MultiplyConstantDivideScaleFactor(Npp8u * pDst_Host, Npp8u  nConstant, int nScaleFactor,  int & nWidth, int & nHeight) {
	for (int i = 0; i < nHeight; i++)
	{
		for (int j = 0; j < nWidth; j++)
		{
			//printf("Before multiply %d\n", pDst_Host[i*nWidth + j]);
			pDst_Host[i*nWidth + j] = pDst_Host[i*nWidth + j] * nConstant/(nScaleFactor-1);
			//printf("After multiply %d\n", pDst_Host[i*nWidth + j]);
		}
	}
	//printf("Constant Value Multiplied...\n");
	//getchar();
}