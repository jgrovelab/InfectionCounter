// Infection Counter, Joe Grove, 2016
// This imagej macro was designed to estimate the percentage of virally infected cells in a monoloayer
// based on the intensity of immunofluorescently labelled viral antigen. 

// An up to date version of the code is maintained at https://github.com/jgrovelab/InfectionCounter

// This text is distributed under a creative commons Attribution-NonCommercial license 
// http://creativecommons.org/licenses/by-nc/3.0/

// Feel free to adapt, improve or appropriate this script to suit your needs.

// The author offers no guarantees of the macro's performance. 
// However, it has been tested on multiple Windows and OSX based machines. 

// This macro processess two channel tif stacks where channel 1 displays cell nuclei and channel 2 (the target channel)
// dislpays viral antigen.

// Script starts. ///////////////////////////////////////////////////////////////////////////////////////////////////// 

// A. User interface. /////////////////////////////////////////////////////////////////////////////////////////////////

// This allows input of critical parameters.  
// These will need to be optimised to fit inidividual experimental procedures.

// Recall preferences
DAPI = call("ij.Prefs.get", "InfectionCounter.DAPI", "4");
Background = call("ij.Prefs.get", "InfectionCounter.Background", "50");
Offset = call("ij.Prefs.get", "InfectionCounter.Offset", "2");
Threshold = call("ij.Prefs.get", "InfectionCounter.Threshold", "1500");
SaveName = call("ij.Prefs.get", "InfectionCounter.SaveName", "Count");

// Create dialog
Dialog.create("Infection Counter: Critical Parameters");

// The noise threshold to find DAPI maxima.
Dialog.addNumber("DAPI Threshold", DAPI);

// The rolling balling width for background correction of the target channel (channel 2).
Dialog.addNumber("C2 Background Correction, Rolling Ball Width", Background);

// A value to be deducted from the target channel (channel 2). This can be used to remove all non-specific signal.
Dialog.addNumber("Offset", Offset);

// The threshold value for a cell to be scored as positive in the target channel (channel 2).
Dialog.addNumber("Threshold", Threshold);

// Save data as
Dialog.addString("Save as...", SaveName);

// Optimisation mode saves processed and annotated images and a data file. This is useful when optimising parameters.
Dialog.addCheckbox("Optimisation Mode", false);

Dialog.show(); 

// Gather values from interface.
DAPI=Dialog.getNumber(); 
Background=Dialog.getNumber();
Offset=Dialog.getNumber();
Threshold=Dialog.getNumber();
SaveName= Dialog.getString() 
Optimisation= Dialog.getCheckbox();

// Write and save preferences
call("ij.Prefs.set", "InfectionCounter.DAPI", DAPI);
call("ij.Prefs.set", "InfectionCounter.Background", Background);
call("ij.Prefs.set", "InfectionCounter.Offset", Offset);
call("ij.Prefs.set", "InfectionCounter.Threshold", Threshold);
call("ij.Prefs.set", "InfectionCounter.SaveName", SaveName);
call("ij.Prefs.savePreferences");

// B. Batch analysis. /////////////////////////////////////////////////////////////////////////////////////////////////

// Clear ROI manager and log.
roiManager("Reset");
print("\\Clear");

// Initiate batch analysis.
   requires("1.33s"); 
   dir = getDirectory("Choose a Directory");
   setBatchMode(true);
   count = 0;
   countFiles(dir);
   n = 0;
   processFiles(dir);
   
   function countFiles(dir) {
      list = getFileList(dir);
      for (i=0; i<list.length; i++) {
          if (endsWith(list[i], "/"))
              countFiles(""+dir+list[i]);
          else
              count++;
      }
  }

   function processFiles(dir) {
      list = getFileList(dir);
      for (i=0; i<list.length; i++) {
          if (endsWith(list[i], "/"))
              processFiles(""+dir+list[i]);
          else {
             showProgress(n++, count);
             path = dir+list[i];
             processFile(path);
          }
      }
  }

  function processFile(path) {
       if (endsWith(path, ".tif")) {
           open(path);

// C. Analysis Pipeline. /////////////////////////////////////////////////////////////////////////////////////////////////

// 1. Ensure image has the correct channel dimensions.
run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices=1 frames=1 display=Color");

// 2. Get image name.
name=getTitle;

// 3. Get image dimensions.
W=getWidth();
H=getHeight();

// 4. Remove scale information.
run("Set Scale...", "distance=1");

// 5. Trim edges by 5 pixels - this eliminates a potential source of artifacts.
makeRectangle(5, 5, (W-10), (H-10));
run("Crop");

// 6. Split channels.
selectWindow(name);
run("Split Channels");

// 7. Find nuclei in DAPI channel (channel 1).
selectWindow("C1-"+name);
run("Find Maxima...", "noise=DAPI output=[Point Selection]");
roiManager("Add");
roiManager("Select", 0);
run("Add Selection...");

// 8. Create voronoi mosaic to approximate cell bodies.
setForegroundColor(250, 250, 250);
newImage("Voronoi", "8-bit black", W, H, 1);
selectWindow("Voronoi");
roiManager("Select", 0);
roiManager("Draw");
run("Make Binary");
run("Voronoi");
setThreshold(1, 255);
run("Convert to Mask");
run("Dilate");

// 9. Add voronois to ROI manager.
roiManager("Reset");
selectWindow("Voronoi");
run("Invert LUT");
run("Analyze Particles...", "add");

// 10. Remove background from target channel (channel 2).
selectWindow("C2-"+name);
run("Subtract Background...", "rolling=Background");

// 11. Subtract offset value from target channel (channel 2).
run("Subtract...", "value=Offset stack");

// 12. Measure fluorescence signal density for each ROI in target channel (channel 2).
run("Set Measurements...", "centroid integrated redirect=None decimal=0");
nROI = roiManager("count");
for (n = 0; n < nROI; n++){
	roiManager("select", n);
	roiManager("Measure");
}

// 13. Calculate percentage positive cells, based on chosen threshold, and add to log.
counter = 0;
for (n=0; n<nResults; n++) {
	Signal = getResult("IntDen", n);
	if (Signal > Threshold) {
		counter++;
	}
}
print(100*counter/nResults);

// 14. Optimisation mode.
// This saves summary images for optimisation.
if (Optimisation){

// 14A. Annotate positive cells on target channel (channel 2).
roiManager("Reset");
selectWindow("C2-"+name);
for (n=0; n<nResults; n++) {
	intDen = getResult("IntDen", n);
	x = getResult("X", n);
	y = getResult("Y", n);

	if (intDen > Threshold) {
             makePoint(x, y);
             roiManager("Add");
             run("From ROI Manager");
	}
}

// 14B. Save annotated images and data file.
saveAs("Results", path+"_data.csv");
selectWindow("C1-"+name);
saveAs("Tiff", path+"_C1_processed");
selectWindow("C2-"+name);
saveAs("Tiff", path+"_C2_processed");
selectWindow("Voronoi");
saveAs("Tiff", path+"_voronoi");
}
// Optimisation mode ends.

// 15. Clear up prior to next loop
roiManager("Reset");
run("Clear Results");
run("Close All");
      }
  }

// 16. Add analysis parameters to log and save data
print("Parameters")
print("DAPI Threshold")
print(DAPI);
print("Background Correction");
print(Background);
print("Offset");
print(Offset);
print("Threshold");
print(Threshold);
selectWindow("Log");
saveAs("text", dir+SaveName+".csv");

// Script end. ///////////////////////////////////////////////////////////////////////////////////////////////////////////// 
