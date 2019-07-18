//latest Version of the E.coli signal accumulation tool
roiManager("reset");
run("Clear Results");
print("\\Clear");

//Create arrays for user variables
WeightChoice = newArray("pure intensity", "MeanStdDev", "pure count");
IntensityEstimation = newArray("Single Pixel", "Mean", "GaussianFit");
MeanStdDev = "MeanStdDev";
pureIntensity = "pure intensity";
pureCount = "pure count";

//Create dialog to grab variabales
Dialog.create("Etact - Ecoli tip accumulation tool  (Version 2.019-05-13)");
Dialog.setInsets(20, 20, 40);
Dialog.addMessage("This tool will estimate accumulated signal of HlyA in E.coli to tip zones.\nMake sure that Ch1 are the HlyA signals and Ch2 the GFP or DAPI signal of induced E.coli.\nThe GFP/Dapi signal will be used to outline the shapes of the E.coli cells.\nFor more Information please contact Sebastian Haensch; Sebastian Haensch@hhu.de");
Dialog.setInsets(0, 80, 0);
Dialog.addCheckbox("Try a channel correction while opening (ideally done before if neccessary)?", false); 
Dialog.setInsets(0, 80, 0);
Dialog.addNumber("Outline size dilation (low = thight; high = wide)", 5);
Dialog.setInsets(0, 80, 0);
Dialog.addMessage("Too wide outlines can push signals out of the tip zone! (min. 1)");
Dialog.setInsets(0, 80, 0);
Dialog.addNumber("Maxima detection threshold (low = sensitive; high = strict)", 10);
Dialog.setInsets(0, 80, 0);
Dialog.addMessage("Sensitive detection threshold can take long time for analysis!");
Dialog.setInsets(0, 80, 0);
Dialog.addCheckbox("Suggest and use an AutoThreshold for Maxima detection", true); 
Dialog.setInsets(0, 120, 0);
Dialog.addChoice("Intensity weighting by pure linear intensity / Mean+-StdDev / without (pure count)", WeightChoice, "pure intensity"); 
Dialog.setInsets(0, 80, 0);
Dialog.addCheckbox("Limit weighting only to bacterial signals", true); 
Dialog.setInsets(0, 80, 0);
Dialog.addMessage("If not checked all background signals are part of weighting estimations!\nNot checking will greatly increase calculation time as well.");
Dialog.addChoice("Sensitivity of signal estimation", IntensityEstimation, "GaussianFit"); 
Dialog.setInsets(0, 80, 0);
Dialog.addMessage("If checked intensity estimation of signals is more precise, \nbut takes more time especially with higher signal counts.");
Dialog.setInsets(40, 0, 0);
Dialog.addNumber("Relative size of tip-zone (low = bigger; high = smaller)", 2);
Dialog.setInsets(0, 80, 0);
Dialog.addMessage("If size of tip is too big, problems with inner non-tip zones can be caused!");
Dialog.setInsets(0, 80, 0);
Dialog.addCheckbox("Use Batchmode for faster calculation (min 5x faster, but no visual output!)", true); 
Dialog.setInsets(0, 0, 0);
Dialog.addCheckbox("Ignore bacteria with low amount of signals:", true); 
Dialog.setInsets(0, 120, 0);
Dialog.addNumber("Minimum required amount of signals for bacteria:", 3);
Dialog.setInsets(0, 120, 0);
Dialog.addNumber("Threshold for accumulation detection (low = sensitive; high = strict)", 1.5);
Dialog.setInsets(0, 0, 0);
Dialog.addMessage("Threshold is used as x-fold increase of signalsscores above signal average of non-tip zones\n Default: If 50% more signalsscores are in the tip-zone\n than the average in non-tip zones, it is classified as accumulated localization/bacterium!");
Dialog.setInsets(0, 120, 0);
Dialog.addCheckbox("Inculde Pres-Blur for maxima positioning (Gaussian; recommended for weak noisy signal)?", false); 
Dialog.setInsets(0, 120, 0);
Dialog.addCheckbox("Inculde Pre-Blur for bacterial outline (Gaussian; recommended for weak noisy signal)?", true); 
Dialog.setInsets(0, 120, 0);
Dialog.addNumber("Range of Gaussian smoothing [px]", 1);
Dialog.setInsets(0, 120, 0);
Dialog.addCheckbox("Using manual threshold for outlines?", true); 
Dialog.setInsets(0, 120, 0);
Dialog.addCheckbox("Provide Sum intensity file for maxima detection?", false); 
Dialog.setInsets(0, 120, 0);
Dialog.addNumber("Size of the detection area [px]", 6);
Dialog.setInsets(0, 0, 0);
Dialog.show();

//Readout variables from user
ChannelCorrection = Dialog.getCheckbox();
Dilation = Dialog.getNumber();
MaxThreshold = Dialog.getNumber();
AutoThresChoice = Dialog.getCheckbox();
StdDevWeighting = Dialog.getChoice();
LimitWeighting = Dialog.getCheckbox();
IntensityFit = Dialog.getChoice();
TipSize = Dialog.getNumber();
BatchMode = Dialog.getCheckbox();
MinimalSignal = Dialog.getCheckbox();
MinimalSignalCount = Dialog.getNumber();
PolarThreshold = Dialog.getNumber();
T1SSBlur = Dialog.getCheckbox();
GFPBlur = Dialog.getCheckbox();
BlurRange = Dialog.getNumber();
ManualThreshold = Dialog.getCheckbox();
ExternalSumIntensityMaxima = Dialog.getCheckbox();
DetectionArea = Dialog.getNumber();
SmallArea=0;
BigArea=0;
TipError = 0;
ResultsCorrection = 0;
onetip=0;
bothtips=0;
background=0;
nothing=0;
firstImage=1;
MaximumError=0;
signalCount=0;

// Initialize some variables and arrays.
run("ROI Manager...");
filename=getInfo("image.filename");
RightSideDistance = newArray();
LeftSideDistance = newArray();
RightSegCount = newArray();
LeftSegCount = newArray();
RightIntCount = newArray();
LeftIntCount = newArray();
RightIntCountnoTip = newArray();
LeftIntCountnoTip = newArray();
RightIntCountTip = newArray();
LeftIntCountTip = newArray();
RightClassSignals = newArray();
LeftClassSignals = newArray();
SkippedName = newArray();
ResArrayText = newArray();
ResArrayNumber = newArray();
DilEffArray = newArray();
IntX = newArray();
SumIntensityGauss = newArray();
SumIntensityMean = newArray();
SumIntensity = newArray();

//Rename channels to generalize script
selectWindow(filename);
run("Split Channels");
selectWindow("C2-"+filename);
rename("GFP");
selectWindow("C1-"+filename);
resetMinAndMax();
rename("T1SS");
run("8-bit");

//If user has choosen channel correction use MultistackReg for possible correction; This would need the plugin turbo-reg as well
if (ChannelCorrection == true) 
{
	run("MultiStackReg", "stack_1=[GFP] action_1=[Use as Reference] file_1=[] stack_2=[T1SS] action_2=[Align to First Stack] file_2=[] transformation=Translation");
	selectWindow("GFP");
	run("Enhance Contrast", "saturated=0.35");
	selectWindow("T1SS");
	run("Enhance Contrast", "saturated=0.35");
}

//Generate Duplication of T1SS for original intensity measurements
selectWindow("T1SS");
run("Duplicate...", "OriginalT1SS");
rename("OriginalT1SS");
selectWindow("T1SS");

// Get ROI and original image dimensions, convert to pixel-based image after.
getPixelSize(unit, pixelWidth, pixelHeight);
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
selectWindow("GFP");
run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");

//Get shape of the bacteria and generate ROIs
selectWindow("GFP");
if(GFPBlur == 1)
{
	run("Gaussian Blur...", "sigma="+BlurRange);
}
run("Median...", "radius=10");

//If manual threshold was choosen, ask user for threshold
if(ManualThreshold == 1)
{
	run("Threshold...");
	waitForUser("Set threshold");
}
else
{
	setAutoThreshold("Percentile dark");
}
getThreshold(lowerThres, upperThres);
setOption("BlackBackground", true);
run("Convert to Mask");
run("Despeckle");
run("Fill Holes");
//run("Median...", "radius=15");
run("Options...", "iterations="+Dilation+" count=1 black do=Dilate");
run("Invert");
roiManager("Show All");
setTool("wand");
run("Colors...", "foreground=white background=black selection=red");

//Ask to mark  obvious artifacts manually, eliminate these from the measurements afterwards
waitForUser("Delete in the ROI-Manager bacteria shapes which are obviously wrong \nor extremely curved!\nAdd the shape of these bacteria by clicking on them and press ´t´ every time!\nPress ´OK´ to proceed!");
if(BatchMode == 1)
{
	setBatchMode(true);
}
starttime=getTime();
roiManager("Show None");
makePoint(0,0);
roiManager("add");
if (roiManager("count") >= 1)
{
	ROIdelete=roiManager("count");
	for (ROIi=0; ROIi<ROIdelete; ROIi++)
	{
		roiManager("select",ROIi);
		roiManager("Fill");
	}
}
roiManager("delete");
run("Invert");
selectWindow("GFP");
run("Duplicate...", "OriginalGFP");
rename("OriginalGFP");
selectWindow("GFP");
run("Analyze Particles...", "size=250-Infinity pixel display exclude add");
ROIbacteria=roiManager("count");

//If option was choosen to limit signals to bacteria outline, erase now all signals that are not included in outlines
if (LimitWeighting == 1)
{
	selectWindow("T1SS");
	run("Duplicate...", "QuantT1SS");
	rename("QuantT1SS");
	selectWindow("GFP");
	run("Invert");
	imageCalculator("Subtract", "T1SS","GFP");
	selectWindow("GFP");
	run("Invert");
}

//If option was choosen to suggest an outo threshold for maxima detection, try to estimate the average intensity of signals and suggest this as threshold
if (AutoThresChoice == 1)
{
	selectWindow("T1SS");
	run("Duplicate...", "AutoThres");
	rename("AutoThres");
	selectWindow("AutoThres");
	setAutoThreshold("Triangle dark");
	run("Set Measurements...", "area mean modal min centroid center feret's limit display redirect=None decimal=4");
	run("Measure", "");
	AutoThres=parseInt(getResultString("Mean", ROIbacteria));
	resetThreshold();
	selectWindow("AutoThres");
	close();
	MaxThreshold = AutoThres;
	ResultsCorrection = 1;
}
selectWindow("T1SS");
run("Enhance Contrast", "saturated=0.35");
run("Set Measurements...", "area mean modal min centroid center feret's display redirect=None decimal=4");

//Measure and readout the center of mass. Store in ROI manager for later use
for (ROIi=0; ROIi<ROIbacteria; ROIi++)
{
	roiManager("select", ROIi);
	run("Measure", "");
	CoMx=parseInt(getResultString("X", ROIi));
	CoMy=parseInt(getResultString("Y", ROIi));
	CoMx=round(CoMx);
	CoMy=round(CoMy);
	makePoint(CoMx,CoMy);
	roiManager("add");	
}
ROIcentroids=roiManager("count");


// Find and mark Spots 
if (ExternalSumIntensityMaxima == 1)
{
	run("Bio-Formats", "");
	filenameSum=getInfo("image.filename");
}
if (T1SSBlur == 1) //if option for signal blur was choosen, use guassian blur for easier identification of T1SS signals
{
	run("Duplicate...", "Blurred Maxima");
	rename("Blurred Maxima");
	selectWindow("Blurred Maxima");
	run("Gaussian Blur...", "sigma="+BlurRange);
}
run("Find Maxima...", "noise="+MaxThreshold+" output=[Single Points] exclude");
setThreshold(255, 255);
run("Convert to Mask");
if (T1SSBlur == 1) //if option for signal blur was choosen, use blurred image now
{
	selectWindow("Blurred Maxima Maxima");
	rename("T1SS Maxima");
}
if (ExternalSumIntensityMaxima == 1) //if option for external sum image was choosen, use this now
{
	selectWindow(filenameSum);
	close();
}
run("Analyze Particles...", "pixel display add"); // use analyze particle function to add them faster to ROI-Manager
selectWindow("T1SS Maxima");
run("Duplicate...", "OriginalMaxima");
rename("OriginalMaxima");
run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 25 25 25 -1\n-1 25 50 25 -1\n-1 25 25 25 -1\n-1 -1 -1 -1 -1\n] normalize"); // Mark spots in quality output
run("Enhance Contrast", "saturated=0.35");
selectWindow("T1SS Maxima");
run("RGB Color");
ROIspots=roiManager("count");
ROIspotsGlobal = ROIspots - ROIcentroids; //set mark as variable to find them in ROI-Manager
roiManager("Show None");

//Enhance and rejoin original images 
selectWindow("OriginalT1SS");
run("Brightness/Contrast...");
run("Enhance Contrast", "saturated=0.35");
run("Red");
selectWindow("OriginalGFP");
run("Brightness/Contrast...");
run("Enhance Contrast", "saturated=0.35");
run("Blue");
selectWindow("OriginalMaxima");
setMinAndMax(0, 15);
run("Green");
run("Merge Channels...", "c1=OriginalT1SS c2=OriginalMaxima c3=OriginalGFP create");

//Estimate and fill arrays with all the intensities of the signals that are found in the image (taking different intesity estimation options into account)
loopCorrection = 0;
for (ROIi=ROIcentroids; ROIi<ROIspots; ROIi++)
{
	if(BatchMode == 1)
	{
		setBatchMode(true);
	}
	selectWindow("QuantT1SS");
	roiManager("select", ROIi);
	run("Set Measurements...", "area mean modal min centroid center feret's display redirect=None decimal=4");
	run("Measure", "");
	//Call first T1SS signal from the manager, readout the 1px intensity and store coordinates
	Pos=roiManager("count")+(ROIi-ROIcentroids);
	ActIntensity= parseInt(getResultString("Mean", Pos+ResultsCorrection));
	getSelectionCoordinates(xpoints, ypoints);
	xpoint=xpoints[1];
	ypoint=ypoints[1];
	SumIntensity= Array.concat(SumIntensity, ActIntensity);
	Array.print(SumIntensity); 
	print(ActIntensity); 

	if (IntensityFit == "GaussianFit") //fill an array for gaussian fit values
	{
		makeRectangle(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
		run("Measure", "");
		Overlay.drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
		run("Plot Profile");
		Plot.getValues(x, y);
		Plot.getLimits(PlotXmin, PlotXmax, PlotYmin, PlotYmax);
		close();
		Fit.doFit(12, x, y);
		a=Fit.p(0);
		b=Fit.p(1);
		c=Fit.p(2);
		d=Fit.p(3);
		x=c;
		GaussMax=(a+(b-a)*exp(-(x-c)*(x-c)/(2*d*d)));
		miss=1-Fit.rSquared();
		if (0 <= c && c <= 20 && miss <= 0.5 && GaussMax <= PlotYmax+1 && GaussMax >= PlotYmin) //do quality control for gaussian fit (not too extreme values >0 <20; no maximum outside of the box, good fit)
		{
			FWHM=2.35482*d*pixelWidth;
			x=c;
			GaussMax=(a+(b-a)*exp(-(x-c)*(x-c)/(2*d*d)));
			print("FWHM: "+FWHM+""+unit+"    Gauss-Intensity: "+GaussMax);
			print("FWHM= "+d+"*2,35482"+pixelWidth);
			ActIntensity= GaussMax;
			SumIntensityGauss= Array.concat(SumIntensityGauss, ActIntensity);
			Array.print(SumIntensityGauss);
			print(ActIntensity);
			print("Test");	
			IJ.deleteRows(nResults-1, nResults-1);
		}
	}
	else if (IntensityFit == "Mean") //fill an array for mean intensity values
	{
		makeRectangle(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
		run("Measure", "");
		Overlay.drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
		ActIntensity= parseInt(getResultString("Mean", Pos+ResultsCorrection+loopCorrection+1));
		SumIntensityMean= Array.concat(SumIntensityMean, ActIntensity);
		Array.print(SumIntensityMean);
		print(ActIntensity);
		loopCorrection++;
	}

}
if(BatchMode == 1)
{
	setBatchMode("exit and display");
}

//Print signal arrays for possible checkpoint and later reviewing. Creating overall statistics for later use / weighting of intensities (dependend on choosen weighted method)
if (IntensityFit == "Single Pixel")
{
	Array.getStatistics(SumIntensity,T1SSmin,T1SSmax,T1SSmean,T1SSstdDev);
	print("SinglePixelIntensityEstimation Mean: "+T1SSmean+"   Min: "+T1SSmin+"   Max: "+T1SSmax+"   stdDev: "+T1SSstdDev);
}
else if (IntensityFit == "Mean")
{
	Array.getStatistics(SumIntensityMean,T1SSmin,T1SSmax,T1SSmean,T1SSstdDev);
	print("MeanIntensityEstimation Mean: "+T1SSmean+"   Min: "+T1SSmin+"   Max: "+T1SSmax+"   stdDev: "+T1SSstdDev);
	SumIntensity=SumIntensityMean;
}
else if (IntensityFit == "GaussianFit")
{
	Array.getStatistics(SumIntensityGauss,T1SSmin,T1SSmax,T1SSmean,T1SSstdDev);
	print("GaussFitIntensityEstimation Mean: "+T1SSmean+"   Min: "+T1SSmin+"   Max: "+T1SSmax+"   stdDev: "+T1SSstdDev);
	SumIntensity=SumIntensityGauss;
}

//run("Tile"); at this position it´s confusing the script. DO NOT USE HERE.

selectWindow("T1SS Maxima");

//accelleration by deleting nonROI T1SS-signals from the manager. For this creating a summed ROI of all outlines and subtract the spots
ROIclean = newArray();
ROIcountTemp = roiManager("count");
print("Checkpoint1");
if (ROIbacteria > 1)
{
	print("Checkpoint2");
	for (ROIi=0; ROIi<ROIbacteria; ROIi++)
	{
		ROIclean = Array.concat(ROIclean, ROIi);
	}
	roiManager("select", ROIclean);
	roiManager("Combine");
	roiManager("add");
	SummedROI = roiManager("count");
		
	for (spot=ROIcentroids; spot<ROIspots;)
	{
		print("Checkpoint3");
		roiManager("select", spot);
		getSelectionCoordinates(xpoints, ypoints);
		xpoint=xpoints[1];
		ypoint=ypoints[1];
		roiManager("select", SummedROI-1);
			if(Roi.contains(xpoint, ypoint)==0)
			{
				roiManager("select", spot);
				roiManager("delete");
				ROIspots = ROIspots-1;
				SummedROI = SummedROI-1;
			}
			else
			{
				spot++;
			}
	}
	roiManager("select", SummedROI-1);
	roiManager("delete");
}
else
{
	print("Checkpoint4");
	ROIclean = ROIbacteria;
}
print("Checkpoint5");
selectWindow("T1SS Maxima");
run("Tile");

//Start analysis-loop for each bacterium using a for-loop within doing: estimating site, tip, intensity, weighting and overall result with readout. Then repeat
for (ROIi=0; ROIi<ROIbacteria; ROIi++)
{
	if(BatchMode == 1)
	{
		setBatchMode(true);
	}
	print("\nDetailed Bacteria #"+ROIi+":");
	print("--------------------------Start original signal measurements");
	T1SSIntSum = newArray();
	acuteError=0;
	ROIbefore=roiManager("count");
	
	//Readout ferets angle and use this to calculate orthogonal limits for both sides.
	FAngle=getResultString("FeretAngle", ROIi);
	FAngle=parseFloat(FAngle);
	if(FAngle>90)
	{
		rBorder=FAngle-90;
		lBorder=-180+rBorder;
	}
	else if(FAngle<90)
	{
		rBorder=FAngle+90;
		lBorder=-180+rBorder;
	}
	
	//Start analysis loop for each signal per bacterium to estimate original intensities
	signalCount=1;
	for (ROIi2=ROIcentroids; ROIi2<ROIspots; ROIi2++)
	{	
		selectWindow("T1SS Maxima");
		roiManager("select", ROIi2);
		//Get signal coordinates
		getSelectionCoordinates(xpoints, ypoints);
		xpoint=xpoints[1];
		ypoint=ypoints[1];
		roiManager("select", ROIi);
		getSelectionBounds(sx, sy, swidth, sheight);
		//Check if signal is part of this or another bacterium to speed up analysis		
		if(Roi.contains(xpoint, ypoint)==1)
		{
			print("Weighting Bacteria #"+ROIi+" signalnumber #"+signalCount);
			selectWindow("T1SS Maxima");
			roiManager("select",ROIi+ROIbacteria);
			CoMx=parseInt(getResultString("X", ROIi+ROIbacteria+ResultsCorrection));
			CoMy=parseInt(getResultString("Y", ROIi+ROIbacteria+ResultsCorrection));
			
			//Visualize distance and angle from center to signal by drawing a line to CoM
			makeLine(CoMx,CoMy,xpoint,ypoint);
			roiManager("add");
			selectWindow("QuantT1SS");
			
			//Determine signal intensity dependend on the user choosen style
			if (IntensityFit == "Single Pixel") //plain readout of the intensity just by single px
			{
						makePoint(xpoint,ypoint);
						run("Set Measurements...", "area mean modal min centroid center feret's display redirect=None decimal=4");
						run("Measure", "");	
						T1SSIntensity = parseInt(getResult('Mean', nResults-1));
			}
			else if (IntensityFit == "GaussianFit") //Gaussian fit over the data withing box. Using the calculated maximum of the curve
			{
				makeRectangle(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				run("Measure", "");
				Overlay.drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				run("Plot Profile");
				Plot.getValues(x, y);
				Plot.getLimits(PlotXmin, PlotXmax, PlotYmin, PlotYmax);
				Fit.doFit(12, x, y);
				close();
				a=Fit.p(0);
				b=Fit.p(1);
				c=Fit.p(2);
				d=Fit.p(3);
				miss=1-Fit.rSquared();
				FWHM=2.35482*d*pixelWidth;
				xpos=c;
				GaussMax=(a+(b-a)*exp(-(xpos-c)*(xpos-c)/(2*d*d)));
				if (0 <= c && c <= 20 && miss <= 0.5 && GaussMax < PlotYmax+1 && GaussMax > PlotYmin ) //Quality management to check for bad fit or weird values (if failed use the maximum and mark in yellow)
				{
					Fit.doFit(12, x, y);
					Fit.plot();
					rename("Gaussfit Plot");
					setColor("black");
	 				drawString("T1SS intensity: "+GaussMax+" R^2: "+miss, 0, 10);
					run("Flatten", "");
					if (firstImage==1) //Generate a vizual output for the user and later reviewing
					{
						selectImage("Gaussfit Plot-1");
						rename("Gaussfit Plots");
						print("first image");
						firstImage=0;
						selectImage("Gaussfit Plot");
						close();
					}
					else 
					{
						run("Copy");
						selectImage("Gaussfit Plots");
						run("Add Slice");
						run("Paste");
						selectImage("Gaussfit Plot");
						close();
						selectImage("Gaussfit Plot-1");
						close();
					}
					print("FWHM: "+FWHM+""+unit+"    Gauss-Intensity: "+GaussMax);
					selectImage("Gaussfit Plots");
					T1SSIntensity= GaussMax;
					selectWindow("Composite");
					setColor(T1SSIntensity*125, T1SSIntensity*125, T1SSIntensity*125);
					drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				}
				else //Use the maximum signal intensity if the gaussian fails and mark these signals by a yellow circle
				{
					selectWindow("T1SS Maxima");
					setColor(150, 150, 0);
					fillOval(xpoint-(getHeight()/120), ypoint-(getHeight()/120),getHeight()/60, getHeight()/60);
					Array.getStatistics(y,Ymin,Ymax,Ymean,YstdDev);
					T1SSIntensity= Ymax;
					MaximumError++;
					acuteError=1;
					selectWindow("Composite");
					fillOval(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				}	
			}
			else if (IntensityFit == "Mean")  //Gaussian fit over the data withing box. Using the calculated maximum of the curve
			{
				makeRectangle(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				run("Measure", "");
				Overlay.drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
				T1SSIntensity = parseInt(getResult('Mean', nResults-1));
				selectWindow("Composite");
				setColor(T1SSIntensity*125, T1SSIntensity*125, T1SSIntensity*125);
				drawRect(xpoint-(DetectionArea/2), ypoint-(DetectionArea/2), DetectionArea, DetectionArea);
			}
			// add the original intensities in an summed array, and delete already used signals, to speed it up
			T1SSIntSum = Array.concat(T1SSIntSum, T1SSIntensity);
			roiManager("select", ROIi2);
			roiManager("delete");
			ROIspots = ROIspots-1;
			ROIbefore = ROIbefore-1;
			ROIi2 = ROIi2-1;
			drawString(signalCount,xpoint,ypoint-10);
			signalCount++;	
			print("-------------------SignalEnd");
		}
		
		
		//speed it up after the active bacteria ROI detecting if spots are still part of the bacterium
		if (ypoint > sy+sheight)
		{
			ROIi2 = ROIspots;
		}
	
	}
	print("-------------------Start weighting");
	ROIafter=roiManager("count");
	//Is all this really necessary?
	FLengthNoScale= parseInt(getResultString("Feret", ROIi));
	FLength = FLengthNoScale*pixelWidth;
	FMinLengthNoScale = parseInt(getResultString("MinFeret", ROIi));
	FMinLength = FMinLengthNoScale*pixelWidth;
	SegmentNoScale = FMinLengthNoScale/TipSize;
	Segment = SegmentNoScale*pixelWidth;
	Length25 = (FLengthNoScale/2)-(SegmentNoScale*3);
	Length50 = (FLengthNoScale/2)-(SegmentNoScale*2);
	Length75 = (FLengthNoScale/2)-(SegmentNoScale*1);
	setColor(90,90,90);
	Length25 = (FLength/2)-(Segment*3);
	Length50 = (FLength/2)-(Segment*2);
	Length75 = (FLength/2)-(Segment*1);
	LeftPol = 0;
	l75 = 0;
	l50 = 0;
	l25 = 0;
	RightPol = 0;
	r75 = 0;
	r50 = 0;
	r25 = 0;
	Intcount = 0;
	oldlength = 0;

	LeftSegCount = newArray();
	RightSegCount = newArray();
	LeftIntCount= newArray(); 
	RightIntCount= newArray();
	RightClassSignals = newArray();
	LeftClassSignals = newArray();
	LeftSegmentError = 0;
	RightSegmentError = 0;
	RightIntCountnoTip = newArray();
	LeftIntCountnoTip = newArray();
	RightIntCountTip = newArray();
	LeftIntCountTip = newArray();
	selectWindow("T1SS Maxima");

	//Start analysis loop to weight and localize the intensities of the bacteria
	signalCount=1;
	for (ROIi2=ROIbefore; ROIi2<ROIafter; ROIi2++)
	{	
		print("Weighting Bacteria #"+ROIi+" signalnumber #"+signalCount);
		roiManager("select", ROIi2);
		run("Set Measurements...", "area mean modal min centroid center feret's display redirect=None decimal=4");
		run("Measure", "");
		getSelectionCoordinates(xpoints, ypoints);
		xpoint=xpoints[1];
		ypoint=ypoints[1];
		length = getResult('Length', nResults-1);
		length = length*pixelWidth;
		PAngle = parseFloat(getResult('Angle', nResults-1));
		T1SSIntensity = T1SSIntSum[Intcount];
		IntWeight = 0;
		print("Original intensity:"+T1SSIntensity);
		
		if (StdDevWeighting == "MeanStdDev") //If style is meanStdDev, everything over Mean+StdDev is 10, everything under Mean-StdDev is 1, everything between Mean-StdDev and Mean+StdDev is between 1 and 10
		{
			
			if(T1SSIntensity <= T1SSmean-T1SSstdDev)
			{
				IntWeight = 1;
			} 
			else if (T1SSIntensity >= T1SSmean+T1SSstdDev)
			{
				IntWeight = 10;
			}
			else
			{
			 	IntRange = T1SSstdDev*2;
			 	IntValue = (T1SSIntensity)-(T1SSmean-T1SSstdDev);
				IntWeight = 1+(IntValue/IntRange)*9;
			}
		}
		else if (StdDevWeighting == "pure intensity") //If style is "pure intensity", lowest found intensity is 1, highest is 10 and all other signals are linearly weighted between 1 and 10 accordingly
		{
			IntRange = T1SSmax;
			IntValue = T1SSIntensity;
			IntWeight = (IntValue/IntRange)*10;
		}
		else //If style is "pure count", no intensity-weighting is done. The signals are just counted, therefore always 1 for intensity score
		{
			IntValue = IntWeight = 1;	
		}

		//Correct for the fiji angle-system to create orthogonal border limits
		if(FAngle < 0 && FAngle >= -90)
		{
			RotateAngle = (360+FAngle)-90;
		}
		else if (FAngle < -90 && FAngle >= -180)
		{
			RotateAngle = (90-abs(FAngle))-90;
		}
		else if (FAngle < 180 && FAngle >= 0)
		{
			RotateAngle = (270-FAngle)-90;
		}

		//Create small and big areas as rectangular approximation. Small is the NoTip-Zone. Big is including the whole bacterium (NoTip- and Tip-Zone)
		selectWindow("T1SS Maxima");
		setColor(255,255,255);
		makeRectangle(CoMx-(FLengthNoScale/2), CoMy-((FMinLengthNoScale*1.2)/2), FLengthNoScale, (FMinLengthNoScale*1.2));
		run("Rotate...", "  angle="+RotateAngle);
		roiManager("add");
		roiManager("select",roiManager("count")-1);
		if (ROIi2 == ROIbefore)
		{
			run("Measure","");
			BigArea = getResult('Area', nResults-1);
			IJ.deleteRows(nResults-1, nResults-1);
			run("Draw", "slice");
		}
		roiManager("rename", "bigger");
		FLengthNoScaleWOtip = FLengthNoScale-(SegmentNoScale*2);
		setColor(180,180,180);
		makeRectangle(CoMx-(FLengthNoScaleWOtip/2), CoMy-((FMinLengthNoScale*1.2)/2), FLengthNoScaleWOtip, (FMinLengthNoScale*1.2));
		run("Rotate...", "  angle="+RotateAngle);
		roiManager("add");
		roiManager("select",roiManager("count")-1);
		if (ROIi2 == ROIbefore)
		{
			run("Measure","");
			SmallArea = getResult('Area', nResults-1);
			IJ.deleteRows(nResults-1, nResults-1);
			run("Draw", "slice");
		}
		roiManager("rename", "smaller");
		roiManager("select", ROIi2);
		getSelectionCoordinates(xpoints, ypoints);
		xpoint=xpoints[1];
		ypoint=ypoints[1];
		roiManager("select", roiManager("count")-1);

		//Start the localization of the weighted signal to right / left tip- or nontip-zone
		if(T1SSIntensity == 0) //double-check not to included artificial signals that are accidently calculated as 0
		{
			setColor(255, 255, 0);
			fillOval(xpoint-(getHeight()/400), ypoint-(getHeight()/400),getHeight()/200, getHeight()/200);
		}
		else if(Roi.contains(xpoint, ypoint)==1) //check if the signal is located in the smaller / nonTip-Zone
		{
			//if so NOTIP event
			print("Signal located in NOtip!");
			if (lBorder < PAngle && PAngle < rBorder)
			{
				//right side event
				RightIntCountnoTip = Array.concat(RightIntCountnoTip, IntWeight);
				print("Signalside: right; Weighted Intensity: "+IntWeight);
				setColor(0,120,0);
			}
			else
			{
				//left side event
				LeftIntCountnoTip = Array.concat(LeftIntCountnoTip, IntWeight);
				print("Signalside: left; Weighted Intensity: "+IntWeight);
				setColor(120,0,0);
			}
			
		}
		else
		{
			// if it is not located in the small area, but in the boundaries of the bacterial-outline (checked earlier), then it must be a tip event	
			print("Signal located in TIP!");
			if (lBorder < PAngle && PAngle < rBorder)
			{
				//right side event
				RightIntCountTip = Array.concat(RightIntCountTip, IntWeight);
				print("Signalside: right; Weighted Intensity: "+IntWeight);
				setColor(0, 255, 0);
				fillOval(xpoint-(getHeight()/400), ypoint-(getHeight()/400),getHeight()/200, getHeight()/200);
			}
			else
			{
				//left side event
				LeftIntCountTip = Array.concat(LeftIntCountTip, IntWeight);
				setColor(255, 0, 0);
				fillOval(xpoint-(getHeight()/400), ypoint-(getHeight()/400),getHeight()/200, getHeight()/200);
				print("Signalside: left; Weighted Intensity: "+IntWeight);
			}
		}
		
		//delete smaller and bigger areas for the next cycle
		roiManager("select", roiManager("count")-1);
		roiManager("delete");
		roiManager("select", roiManager("count")-1);
		roiManager("delete");	
		//Create visual outputs
		selectWindow("T1SS Maxima");
		drawLine(CoMx,CoMy,xpoint,ypoint);
		drawString(IntWeight,xpoint,ypoint);	
		setColor(IntWeight*25, IntWeight*25, IntWeight*25);
		drawOval(xpoint-(getHeight()/200), ypoint-(getHeight()/200),getHeight()/110, getHeight()/110);
		Intcount++;
		print("-------------------signalend");
		signalCount++;
	}

	//Check for errors and add up the signals
	AverageNoTip=0;
	AverageTip=0;
	if (RightSegmentError == 0)
	{
		for (Count=0; Count<RightIntCountnoTip.length; Count++)	
		{
			if (Count == 0)
			{		
				AverageNoTip = RightIntCountnoTip[Count];
			}
			else 
			{
				AverageNoTip = AverageNoTip + RightIntCountnoTip[Count];
			}
		}
		
		for (Count=0; Count<RightIntCountTip.length; Count++)	
		{
			if (Count == 0)
			{	
				AverageTip = RightIntCountTip[Count];
			}
			else 
			{
				AverageTip = AverageTip + RightIntCountTip[Count];
			}
		}
		RightCount = AverageNoTip;
		RightPol = AverageTip;
	}
	else
	{
		RightCount = 0;
		RightPol = 0;
	}
	
	AverageNoTip=0;
	AverageTip=0;
	if (LeftSegmentError == 0)
	{
		for (Count=0; Count<LeftIntCountnoTip.length; Count++)	
		{
			if (Count == 0)
			{
				AverageNoTip = LeftIntCountnoTip[Count];
			}
			else 
			{
				AverageNoTip = AverageNoTip + LeftIntCountnoTip[Count];
			}
		}
		
		for (Count=0; Count<LeftIntCountTip.length; Count++)	
		{
			if (Count == 0)
			{
				AverageTip = LeftIntCountTip[Count];
			}
			else 
			{
				AverageTip = AverageTip + LeftIntCountTip[Count];
			}
		}
		LeftCount = AverageNoTip;
		LeftPol = AverageTip;
	}
	else
	{
		LeftCount = 0;	
		LeftPol = 0;
	}

	print("BEFORE leftCount:"+LeftCount+"   left tip Score:"+LeftPol);
	print("BEFORE rightCount:"+RightCount+"   right tip Score:"+RightPol);

	//Calculate the threshold and intensity-scores needed, to potentially classify as a polarized accumulated bacterium
	MainAverage = (RightCount+LeftCount)/SmallArea;
	RightPol = RightPol/((BigArea-SmallArea)/2);
	LeftPol = LeftPol/((BigArea-SmallArea)/2);
	LeftADD = MainAverage*PolarThreshold;
	print(LeftADD+" Score threshold for left ; MainAverage:"+MainAverage+"   left tip Score:"+LeftPol);
	RightADD = MainAverage*PolarThreshold;
	print(RightADD+" Score threshold for right ; MainAverage:"+MainAverage+"   right tip Score:"+RightPol);
	if(MinimalSignal == 1)
	{
		// print("Signalcount:   "+signalCount); Correcting "signalCount" for quality control of bacteria (ignore bacteria with less signal than : Userdefined)
		signalCount = signalCount-1;
	}
	
	//Finally classify the bacterium and display the results
	if ((FLengthNoScale-(SegmentNoScale*2)) <= SegmentNoScale) // If the notip-zone is smaller than the tip-zone it is a size error --> rejected
	{
		print ("BACTERIA SIZE ERROR !!! Not Counted");
		ResArrayText = Array.concat(ResArrayText, "Bacteria Size Error");
		ResArrayNumber=Array.concat(ResArrayNumber, 1);
		background = background+1;
		roiManager("select", ROIi);
		roiManager("Set Color", "cyan");
		roiManager("Set Line Width", 2);
		roiManager("Draw");
	}
	else if(LeftPol == 0 && RightPol == 0 && MainAverage == 0) // If there are no signals at all in the bacterium it is an artifact --> rejected
	{
		print ("No spots detected in selection and classified as background");
		ResArrayText = Array.concat(ResArrayText, "NO Signals (Background?!)");
		ResArrayNumber=Array.concat(ResArrayNumber, 1);
		background = background+1;
		roiManager("select", ROIi);
		roiManager("Set Color", "yellow");
		roiManager("Set Line Width", 2);
		roiManager("Draw");
	}
	else if(signalCount < MinimalSignalCount && MinimalSignal == 1) // If there are no signals at all in the bacterium it is an artifact --> rejected
	{
		
		print ("Too less Signals detected");
		ResArrayText = Array.concat(ResArrayText, "Too Less Signals");
		ResArrayNumber=Array.concat(ResArrayNumber, 1);
		background = background+1;
		roiManager("select", ROIi);
		roiManager("Set Color", "magenta");
		roiManager("Set Line Width", 2);
		roiManager("Draw");
	}
	else if (LeftADD < LeftPol && RightADD < RightPol) // If tip-criterium met on both sides --> double sided polarized accumulation
	{
		print ("Polarized accumulation on both tips detected");
		ResArrayText = Array.concat(ResArrayText, "Both accumulated!");
		ResArrayNumber=Array.concat(ResArrayNumber, 1);
		bothtips = bothtips+1;
		roiManager("select", ROIi);
		roiManager("Set Color", "white");
		roiManager("Set Line Width", 2);
		roiManager("Draw");
	} 
	else if (LeftADD >= LeftPol && RightADD >= RightPol) // If tip-criterium is not met on both sides --> no-polarized accumulation
	{
		print ("Nothing for both sides!");
		ResArrayText = Array.concat(ResArrayText, "Nothing!");
		ResArrayNumber=Array.concat(ResArrayNumber, 1);
		nothing = nothing+1;
		roiManager("select", ROIi);
		roiManager("Set Color", "blue");
		roiManager("Set Line Width", 2);
		roiManager("Draw");
	}
	else //if none of the criteria met, it must be a single sided polarized accumulated cell. Check if it is right or left. Both cases will increase the 1-tip count by 1.
	{
		if (LeftADD < LeftPol)
		{
			print("Polarized accumulation on left side (red) detected!");
			ResArrayText = Array.concat(ResArrayText, "YES left, ");
			onetip = onetip+1;
			roiManager("select", ROIi);
			roiManager("Set Color", "red");
			roiManager("Set Line Width", 2);
			roiManager("Draw");
		} 
		else
		{
			print("No accumulation on left side (red)!");
			ResArrayText = Array.concat(ResArrayText, "NO left");
			onetip = onetip+1;
			
		}
		if (RightADD < RightPol)
		{
			print("Polarized accumulation on right side (green) detected!");
			ResArrayText = Array.concat(ResArrayText, "YES right, ");
			roiManager("select", ROIi);
			roiManager("Set Color", "green");
			roiManager("Set Line Width", 2);
			roiManager("Draw");
		} 
		else
		{
			print("No accumulation on right side (green)!");
			ResArrayText = Array.concat(ResArrayText, "NO right");
		}
		ResArrayNumber=Array.concat(ResArrayNumber, 2);
	}
	if(BatchMode == 1)
	{
		setBatchMode("exit and save");
	}
	//Display all the images and ignore the labels
	roiManager("Show All without labels");
	roiManager("Show None");
	print("#######################################################------bacteriumEnd");
}

//Labeling the Single Bacteria
setFont("Serif", (getHeight()/50), "bold");
selectWindow("T1SS Maxima");
setColor("white");
for (ROIi=0; ROIi<ROIbacteria; ROIi++)
{
	roiManager("select",ROIi+ROIbacteria);
	CoMx=parseInt(getResultString("X", ROIi+ROIbacteria+ResultsCorrection));
	CoMy=parseInt(getResultString("Y", ROIi+ROIbacteria+ResultsCorrection));
	BacNumber=toString(ROIi);
	drawString(BacNumber,CoMx,CoMy);
}

// Restore image dimensions

selectWindow("T1SS");
run("Set Scale...", "distance=1 known="+pixelWidth+" pixel=1 unit="+unit);
close();
selectWindow("QuantT1SS");
run("Enhance Contrast", "saturated=0.35");
run("Set Scale...", "distance=1 known="+pixelWidth+" pixel=1 unit="+unit);
selectWindow("T1SS Maxima");
run("Set Scale...", "distance=1 known="+pixelWidth+" pixel=1 unit="+unit);

//Final text for results
//Print all the parameter used for this analysis
print("\n\n\nChoosen Parameters:");
print("Do Channel Correction?: "+ChannelCorrection);
print("DilationFactor: "+Dilation);
print("Maximum Threshold: "+MaxThreshold);
print("Suggest Auto Threshold: "+AutoThresChoice);
print("Procedure for intensity weighting?: "+StdDevWeighting);
print("Limit weighting only to bacterial signals?: "+LimitWeighting);
print("Procedure for intensity estimation?: "+IntensityFit);
print("Tip size Factor?: "+TipSize);
print("Use Batch Mode?: "+BatchMode);
print("Accumulation Threshold?: "+PolarThreshold);
print("Use Pre-Blur for T1SS-Signal positioning?: "+T1SSBlur);
print("Use Pre-Blur for GFP-Bacterial outlining?: "+GFPBlur);
print("Sigma for Gaussian Pre-Blur [px]?: "+BlurRange);
print("Use manual Thresholding for Outlining?: "+ManualThreshold);
print("Final lower Threshold for outlines: "+lowerThres);
print("Final upper Threshold for outlines: "+upperThres);
print("Use external file for T1SS sum intensities for positioning?: "+ExternalSumIntensityMaxima);
print("Size of the signal intensity estimation window?: "+DetectionArea);
print("\n\n\n########################################################################");
print("\n\n\n Threshold for polarized accumulation:");
print(" In the tip must be "+(PolarThreshold-1)*100+"% more signal scores than the average");
print(" signal count in non-tip areas.");
print("\nNow "+ROIspotsGlobal+" Maxima in total were analyzed! "); 
print("\nDuring measurement for "+MaximumError+" of the Maxima, maximum intensity was used\n due to unsuccessful fit."); 

//Create the plot for intensities found for all the T1SS-signals and dependend on the style of intensity wheighting
Array.sort(SumIntensity); 
for (int=0; int<SumIntensity.length; int++)
{
	IntX = Array.concat(IntX, int);
}
Plot.create("Intensities", "Maximum", "Grey values", IntX, SumIntensity);
Plot.setLimits(0, SumIntensity.length, 0, T1SSmax);
Plot.setColor("red");
found=0;
LowDevBound=0;
MeanBound=0;
HighDevBound=SumIntensity.length;
for (i=0; i<SumIntensity.length; i++)
{
	 if (SumIntensity[i]>=round(T1SSmean-T1SSstdDev) && found == 0)
	 {
	 		LowDevBound=i;
	 		found = 1;
	 }
	 if (SumIntensity[i]>=round(T1SSmean) && found == 1)
	 {
	 		MeanBound=i;
	 		found = 2;	
	 }
	 if (SumIntensity[i]>=round(T1SSmean+T1SSstdDev) && found == 2)
	 {
	 		HighDevBound=i;
	 		i=SumIntensity.length+1;
	 }	 
}
if(StdDevWeighting == "MeanStdDev")
{
	xstart=0;
	xend=LowDevBound;
	heightstart=T1SSmax/10;
	heightend=T1SSmax/10;
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	Plot.setColor("blue");
	xstart=0;
	xend=LowDevBound;
	heightstart=(T1SSmean-T1SSstdDev);
	heightend=(T1SSmean-T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	Plot.setColor("red");
	xstart=LowDevBound;
	xend=HighDevBound;
	heightstart=(T1SSmax/10);
	heightend=(T1SSmax-(T1SSmax/10));
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=HighDevBound;
	xend=SumIntensity.length;
	heightstart=T1SSmax-(T1SSmax/10);
	heightend=T1SSmax-(T1SSmax/10);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);
	
	Plot.setColor("blue");
	xstart=0;
	xend=SumIntensity.length;
	heightstart=T1SSmean;
	heightend=T1SSmean;
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=HighDevBound;
	xend=SumIntensity.length;
	heightstart=(T1SSmean+T1SSstdDev);
	heightend=(T1SSmean+T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);
	Plot.setLegend("Intensities\nWeighting\nMean and stdDevs", "top-left");
}
else if (StdDevWeighting == "pure intensity")
{
	xstart=0;
	xend=SumIntensity.length;
	heightstart=0;
	heightend=T1SSmax;
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	Plot.setColor("blue");
	xstart=0;
	xend=LowDevBound;
	heightstart=(T1SSmean-T1SSstdDev);
	heightend=(T1SSmean-T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=0;
	xend=SumIntensity.length;
	heightstart=T1SSmean;
	heightend=T1SSmean;
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=HighDevBound;
	xend=SumIntensity.length;
	heightstart=(T1SSmean+T1SSstdDev);
	heightend=(T1SSmean+T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);
	Plot.setLegend("Intensities\nWeighting\nMean and stdDevs", "top-left");
}
else
{
	Plot.setColor("blue");
	xstart=0;
	xend=LowDevBound;
	heightstart=(T1SSmean-T1SSstdDev);
	heightend=(T1SSmean-T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=0;
	xend=SumIntensity.length;
	heightstart=T1SSmean;
	heightend=T1SSmean;
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);

	xstart=0;
	xend=SumIntensity.length;
	heightstart=(T1SSmean+T1SSstdDev);
	heightend=(T1SSmean+T1SSstdDev);
	xValues = newArray(xstart, xend);
	yValues = newArray(heightstart, heightend); 
	Plot.add("line", xValues, yValues);
	Plot.setLegend("Intensities\nMean and stdDevs", "top-left");
}
Plot.setColor("black");
Plot.show();

//Print what was the suggestion for autothreshold
if (AutoThresChoice == 1)
{
	print("Suggested autothreshold for maximum detection was: "+floor(AutoThres));
}

//Print detailed results for each bacterium
for (ROIi=0; ROIi<ROIbacteria; ROIi++)
{
	print("\nResults for bacteria No."+ROIi+" :");
	number=0;
	for (i=0; i<ROIi; i++)
	{
		number=number+ResArrayNumber[i];
	}

	if (ResArrayNumber[ROIi] ==1)
	{
		print("    "+ResArrayText[number]);	
	} 
	else
	{
		print("    "+ResArrayText[number]+" "+ResArrayText[number+1]);	
	}
}

//Print out the overall results
print("\nOverall:\n   2-tips: "+bothtips+"    1-tips: "+onetip+"    Nothing: "+nothing+"    Background/Error: "+background);
selectWindow("QuantT1SS");
selectWindow("T1SS Maxima");
roiManager("Show All without labels");
roiManager("Show None");
if(BatchMode == 1)
{
	setBatchMode("exit and save");
}

//Print out the overall time result
endtime=getTime();
timeDifference=endtime-starttime;
seconds = timeDifference/1000;
minutes = floor(seconds/60);
seconds = seconds - minutes*60;
hours = floor(minutes/60);
minutes = minutes - hours*60;
print("\nIt took "+hours+"hours, "+minutes+"minutes and "+seconds+"seconds for calculation");