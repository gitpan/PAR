//**************************************
//INCLUDE files for :File2ResourceAdder
//**************************************
windows.h
winbase.h
stdio.h
string.h
time.h

//**************************************
// Name: File2ResourceAdder
// Description:File2ResourceAdder adds files found in the current directory to a Windows PE-file with resources (e.g. EXE/DLL, no RES/RC) as binary data (RT_RCDATA) with the file name (without extension) as the resource name.
It's a commandline tool for windows.
// By: Holger Sauer
//
//
// Inputs:None
//
// Returns:None
//
//Assumes:File2ResourceAdder
The File2ResourceAdder (also called "F2RA" within this document) searches the
current(!) directory and adds all files it finds as resources to a MS Windows
resource file (e.g. DLL or EXE, but no RES or RC). The new resources will have
as their name the filename (without extension) in capital letters and their type
will be RT_RCDATA as their content is stored as binary data.
During testing F2RA it appeared, that it could only handle about 30-40 files
one time, so please split your files if it's too big. It also can only handle
files smaller than 64kB.
To use F2RA, please run the executable program with the target resource file
as its first parameter.
File2ResourceAdder was written in April 2003 by Holger Sauer (www.h-sauer.de)
All rights are reserved. It is published under the GNU GPL 2.
//
//Side Effects:It does only add about 30-40 files at once, so please split your directories, it you have more files. The file size must also fit.
//This code is copyrighted and has limited warranties.
//Please see http://www.Planet-Source-Code.com/xq/ASP/txtCodeId.6051/lngWId.3/qx/vb/scripts/ShowCode.htm
//for details.
//**************************************

/*
File2ResourceAdder
Copyright (C) 2003 Holger Sauer, Leipzig/Germany
--------------------------------------------------------------------------------
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.
You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
--------------------------------------------------------------------------------
File name:ResCreator.c
Description: File2ResourceAdder - commandline version
Created: 08.04.2003
Updated: 10.04.2003
*/
#define _WIN32_WINNT 0x0400
#include "windows.h"
#include "winbase.h"
#include <stdio.h>
#include <string.h>
#include <time.h>
#ifndef CLOCKS_PER_SEC
#define CLOCKS_PER_SEC CLK_TCK
#endif
// delay some milliseconds
void delay(unsigned short msec)


    {
    clock_t t0;
    unsigned long diff = 0L;
    for (t0 = clock(); diff < (unsigned long)msec; )


        {
        diff = (unsigned long)(clock() - t0);
        diff *= 1000L;
        diff /= CLOCKS_PER_SEC;
    }
}
// this has to be high enough for number of elements in split array!
#define MAXELEMENTS 20
// split string elements
char **split_string (char *delim, char *str)


    {
    char *token;
    static char *list[MAXELEMENTS];
    int i = 0;
    token = strtok(str, delim);
    list[i++] = token;
    while( ((token = strtok(NULL, delim)) != NULL) &&
    (i < MAXELEMENTS))


        {
        /*buffer overflow is bad.*/
        list[i++] = token;
    }
    return(list);
}
// do resource-adding for given file
void DoItWithFile(char *FileName, DWORD FileSize, HANDLE hUpdateRes)


    {
    BOOL result; 
    FILE *stream;
    char *lpResBuffer;
    long lngResLength = 0;
    long lngSize = 0;
    char **splitstring;
    if ((stream = fopen(FileName, "r")) == NULL)


        {
        printf("Cannot open source file %s for reading.", FileName);
    }
    else


        {
        // get file size 
        rewind (stream);
        lpResBuffer = (char*) malloc (FileSize + 128);
        if (lpResBuffer == NULL)


            {
            printf("Could not reserve memory for temporary file buffer.\n");
        } 
        else


            {
            lngSize = 0;
            // load file content
            while (!feof(stream))


                {
                	if (lngSize < (FileSize + 128))


                    	{
                    	 lpResBuffer[lngSize] = fgetc(stream);
                    	 lngSize++;
                    	}
                }
                lpResBuffer[lngSize+1] = 0;
                // change file names etc.
                splitstring = split_string(".",_strupr(FileName));
                printf("Resource: %s (Size: %d Extension: %s).\n", splitstring[0], lngSize, splitstring[1]);
                // update resource file
                result = UpdateResource(hUpdateRes,
                RT_RCDATA,
                splitstring[0],
                MAKELANGID(LANG_NEUTRAL, SUBLANG_NEUTRAL),
                lpResBuffer,
                lngSize);
                if (!result) 


                    { 
                    	printf("Could not add resource."); 
                } 
                free(lpResBuffer);
            }
            fclose(stream);
        }
    }
    // do main stuff
    int main(int argc, char *argv[])


        {
        WIN32_FIND_DATA FindFileData;
        HANDLE hFind;
        HANDLE hUpdateRes;
        char *DLLFile;
        BOOL fFinished = FALSE;
        long lngFFLength = 0;
        int i = 0;
        printf("File2ResourceAdder\nWritten by Holger Sauer (www.h-sauer.de)\n\n");
        if (argc < 2)


            {
            printf("Not enough parameters given.\n");
            	//printf("X: " RT_HTML ".\n");
        }
        else


            {
            if ((strcmp(argv[1],"-h") == 0) || (strcmp(argv[1],"-?") == 0) || (strcmp(argv[1],"/?") == 0) || (strcmp(argv[1],"/h") == 0))


                {
                printf("%s [-?|FileName]\n"
                "options: -?- display this help screen\n"
                " FileName - name of file the resources are to be added\n"
                "File2ResourceAdder searches the current directory\n"
                "and adds all files as resources to a given file.\n", argv[0]);
            }
            else


                {
                // open resource file
                DLLFile = argv[1];
                hUpdateRes = BeginUpdateResource(DLLFile, FALSE); 
                if ((hUpdateRes == NULL) || (hUpdateRes == 0))


                    {
                    printf("Error opening target file %s.\n", DLLFile);
                }
                else if (hUpdateRes < 0)


                    {
                    printf("Error opening target file %s.\n", DLLFile);
                }
                else


                    {
                    printf("Used target file: %s.\n",argv[1]);
                    hFind = FindFirstFile("*.*", &FindFileData);
                    if (hFind == INVALID_HANDLE_VALUE)


                        {
                        printf ("Invalid file handle. Error is %d\n", GetLastError ());
                    }
                    else


                        { 
                        while (!fFinished)


                            {
                            if ((strcmp(FindFileData.cFileName,".") == 0) || (strcmp(FindFileData.cFileName,"..") == 0))


                                {
                                // skip system directories
                            }
                            else if (FindFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)


                                {
                                // skip directories
                            }
                            else


                                {
                                lngFFLength = (FindFileData.nFileSizeHigh * (MAXDWORD)) + FindFileData.nFileSizeLow;
                                DoItWithFile(FindFileData.cFileName, lngFFLength, hUpdateRes);
                            }
                            if (!FindNextFile(hFind, &FindFileData)) 


                                {
                                if (GetLastError() == ERROR_NO_MORE_FILES) 


                                    { 
                                    fFinished = TRUE;
                                    printf("Done.");
                                }
                                else


                                    {
                                    printf("Cannot find next file.\n");
                                }
                            }
                        } 
                    } 
                }	
                if (!EndUpdateResource(hUpdateRes, FALSE)) 


                    { 
                    printf("Could not write changes to file."); 
                } 
                else


                    {
                    printf("Changes written to target file.\n");
                }
            }
        }
        return (0);
    }

		</xmp>

