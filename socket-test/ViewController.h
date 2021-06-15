//
//  ViewController.h
//  socket-test
//
//  Created by Natale Galioto on 03/06/21.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *sentText;
@property (weak, nonatomic) IBOutlet UITextField *receivedText;
@property (weak, nonatomic) IBOutlet UISegmentedControl *interfacesSelector;
@property (weak, nonatomic) IBOutlet UITextField *destinationIP;

- (int) receiveFromUDP;

@end

