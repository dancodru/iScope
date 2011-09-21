#import <UIKit/UIKit.h>

@class GraphView;

extern int OpenSerialPort(int serialSpeed);
extern int WriteSerial(int fd, void *buf, size_t n);
extern int ReadSerial(int fd, void *buf, size_t n);
extern void CloseSerial(int fd);

@interface MainViewController : UIViewController<UIAccelerometerDelegate>
{
	GraphView *graphView;
	UIButton *pauseButton;
    UILabel *xValueLabel;
    UILabel *yValueLabel;
    UILabel *zValueLabel;

	BOOL isPaused;

    int divider;
    
    double updateFrequency;
    
    int serialFD;
}

@property(nonatomic, retain) IBOutlet GraphView *graphView;
@property(nonatomic, retain) IBOutlet UIButton *pauseButton;
@property(nonatomic, retain) IBOutlet UILabel *xValueLabel;
@property(nonatomic, retain) IBOutlet UILabel *yValueLabel;
@property(nonatomic, retain) IBOutlet UILabel *zValueLabel;

-(IBAction)pauseButtonPressed:(id)sender;

@end