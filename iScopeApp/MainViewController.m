#import "MainViewController.h"
#import "GraphView.h"

#define kUpdateFrequency	60.0
#define kLabelFrequency     10 // divider

#define kLocalizedPause		NSLocalizedString(@"Pause","pause taking samples")
#define kLocalizedResume	NSLocalizedString(@"Resume","resume taking samples")

@interface GraphData : NSObject
{
@public
    double x, y, z;
}

@property(nonatomic,readwrite) double x;
@property(nonatomic,readwrite) double y;
@property(nonatomic,readwrite) double z;

@end

@implementation GraphData
@synthesize x, y, z;
@end

@interface MainViewController()

@end

@implementation MainViewController

@synthesize graphView, pauseButton, xValueLabel, yValueLabel, zValueLabel; 

// Subclasses override this method to define how the view they control will respond to device rotation 
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (interfaceOrientation == UIDeviceOrientationLandscapeLeft ||
        interfaceOrientation == UIDeviceOrientationLandscapeRight) {
        return YES;
    }
    else
    {
        return NO;
    }
}

// Implement viewDidLoad to do additional setup after loading the view.
-(void)viewDidLoad
{
	[super viewDidLoad];
	
    isPaused = YES;
    [pauseButton setTitle:kLocalizedResume forState:UIControlStateNormal];

    divider = 0;
	[[UIAccelerometer sharedAccelerometer] setUpdateInterval:1.0 / kUpdateFrequency];
//	[[UIAccelerometer sharedAccelerometer] setDelegate:self];
	
	[graphView setIsAccessibilityElement:YES];
	[graphView setAccessibilityLabel:NSLocalizedString(@"unfilteredGraph", @"")];
    
    NSOperationQueue *queue = [NSOperationQueue new];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] 
                                        initWithTarget:self
                                        selector:@selector(readSerial) 
                                        object:nil];
    [queue addOperation:operation]; 
    [operation release];
}

#define CHANNELS 3
#define FREQ 50.0

typedef struct {
    char Channels;
    char BytesPerSample;
    char IDAC_Value;
    unsigned char VDAC_Value;
    uint Period;
} SendHeader;

typedef union {
    SendHeader Header;
    char buff[8];
} TxBuffer;

typedef union {
    int nums[CHANNELS];
    char buff[CHANNELS * 4];
} RxBuffer;

- (void)readSerial 
{
    for (; ; ) {
        if (isPaused == YES) {
            [NSThread sleepForTimeInterval:0.02];
        }
        else {
            // 1843200 921600 460800
            serialFD = OpenSerialPort(460800);
            
            double maxValue = (double)(1 << 19);
            RxBuffer data;
            
            //char buff[] = { 0x03, 0x04, 0x60, 0x01, 0x12, 0x00, 0x0A, 0x64 };
            TxBuffer txBuffer;
            txBuffer.Header.Channels = 0;
            
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            [NSThread sleepForTimeInterval:0.1];
            
            txBuffer.Header.Channels = CHANNELS;
            txBuffer.Header.BytesPerSample = 4;
            double sampleFrequency = FREQ; // Hz
            txBuffer.Header.Period = (uint)(5900000.0 / sampleFrequency);
            txBuffer.Header.IDAC_Value = 10;
            txBuffer.Header.VDAC_Value = 100;
            
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            GraphData *graphData = [GraphData alloc];

            for (; ; ) {
                if (graphView != nil && isPaused == NO) {
                    ReadSerial(serialFD, data.buff, 4 * CHANNELS);
                    
                    graphData.x = data.nums[0] / maxValue;
                    graphData.y = data.nums[1] / maxValue;
                    graphData.z = data.nums[2] / maxValue;
                    
                    [self performSelectorOnMainThread:@selector(addData:) withObject:graphData waitUntilDone:NO];
                    //[graphView addX:graphData.x y:graphData.y z:graphData.z];
                    //[self performSelectorOnMainThread:@selector(refreshView:) withObject:nil waitUntilDone:NO];
                }
                else {
                    break;
                }
            }

            txBuffer.Header.Channels = 0;
            WriteSerial(serialFD, txBuffer.buff, 8);
            
            CloseSerial(serialFD);

            [graphData release];
        }
        
        if (graphView == nil){
            break;
        }
    }
}

-(void)refreshView:(NSObject *)obj
{
    [graphView advanceSegments];
}

-(void)addData:(GraphData *)graphData
{
    [graphView addX:graphData.x y:graphData.y z:graphData.z];
    divider++;
    if (divider % kLabelFrequency == 0) {
        NSString *xText = [NSString stringWithFormat:@"X:%.3f", graphData.x * 1024.0];
        NSString *yText = [NSString stringWithFormat:@"Y:%.3f", graphData.y * 1024.0];
        NSString *zText = [NSString stringWithFormat:@"Z:%.3f", graphData.z * 1024.0];
        
        xValueLabel.text = xText;
        yValueLabel.text = yText;
        zValueLabel.text = zText;
    }
}

-(void)viewDidUnload
{
	[super viewDidUnload];
	self.graphView = nil;
    self.pauseButton = nil;
    self.xValueLabel = nil;
    self.yValueLabel = nil;
    self.zValueLabel = nil;
}

// UIAccelerometerDelegate method, called when the device accelerates.
-(void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
	// Update the accelerometer graph view
	if(!isPaused)
	{
		[graphView addX:acceleration.x y:acceleration.y z:acceleration.z];
        
        divider++;
        if (divider % kLabelFrequency == 0) {
            NSString *xText = [NSString stringWithFormat:@"X:%.3f", acceleration.x];
            NSString *yText = [NSString stringWithFormat:@"Y:%.3f", acceleration.y];
            NSString *zText = [NSString stringWithFormat:@"Z:%.3f", acceleration.z];
            
            xValueLabel.text = xText;
            yValueLabel.text = yText;
            zValueLabel.text = zText;
        }
	}
}

-(IBAction)pauseButtonPressed:(id)sender
{
	if(isPaused)
	{
		// If we're paused, then resume and set the title to "Pause"
		isPaused = NO;
		[pauseButton setTitle:kLocalizedPause forState:UIControlStateNormal];
	}
	else
	{
		// If we are not paused, then pause and set the title to "Resume"
		isPaused = YES;
		[pauseButton setTitle:kLocalizedResume forState:UIControlStateNormal];
	}
	
	// Inform accessibility clients that the pause/resume button has changed.
	UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

-(void)dealloc
{
	// clean up everything.
	[graphView release];
	[pauseButton release];
	[xValueLabel release];
	[yValueLabel release];
	[zValueLabel release];

	[super dealloc];
}

@end
