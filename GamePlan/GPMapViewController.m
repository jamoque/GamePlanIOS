//
//  GPMapViewController.m
//  GamePlanIOS
//
//  Created by Jeremy Hintz on 6/7/14.
//  Copyright (c) 2014 Game Plan. All rights reserved.
//

#import "GPMapViewController.h"
#import "TransitionDelegate.h"
#import "UzysSlideMenu.h"
#import "EditEventVC.h"
#import "GPEventDetailViewController.h"
#import "Tailgate.h"
#import "AfterParty.h"
#import "WatchParty.h"
#import "Restaurant.h"
#import "Game.h"

@interface GPMapViewController ()

@property (nonatomic, strong) TransitionDelegate *transitionController;
@property CLLocationManager *locationManager;
@property CLLocation *currentLocation;
@property (nonatomic,strong) UzysSlideMenu *bottomBarMenu; //UzysSlideMenu is part of an outside library that we modified
@property (nonatomic, strong) Event *event;

@end

//Coordinates of Bob Bullock Museum
#define BB_LAT 30.2804859;
#define BB_LONG -97.7386164;

//Span
#define ZOOM 0.02f;

@implementation GPMapViewController
@synthesize transitionController;

BOOL userAllowedLocationTracking;
BOOL userLocationUpdatedOnce;
BOOL tailgatesVisible;
BOOL afterPartiesVisible;
BOOL restaurantsVisible;
int timeInSecondsSinceLocationSavedInParse;
NSDate *today;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.hidden = YES;
    
    today = [NSDate date];
    [self setGameSchedule];
    [self initializeFilterParameters];
    
    // This is what allows us to pop transluscent modals
    self.transitionController = [[TransitionDelegate alloc] init];
    self.mapView.delegate = self;
    [self setUpLocationManager];
    [self loadEventPins];
    [self setProfilePhoto];
    [self initializeMenus];
}

- (void)viewDidAppear:(BOOL)animated
{
    // Check to see if the user is logged in, and if not pop up a FBLoginViewController
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *currentUserLoggedIn = [defaults objectForKey:@"userLoggedIn"];
    if (!([currentUserLoggedIn isEqualToString:@"YES"]))
    {
        // Reference to facebook log in view controller drawn in Main.storyboard
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        GPFacebookLoginViewController *facebookLoginViewController = [storyboard instantiateViewControllerWithIdentifier:@"FBLogin"];
        facebookLoginViewController.userProfilePictureButtonForMapViewController = self.userProfileImageButton;
        facebookLoginViewController.topBarForMapViewController = self.topBar;
        facebookLoginViewController.bottomBarForMapViewController = self.bottomBar;
        facebookLoginViewController.searchBarForMapViewController = self.searchBar;
        facebookLoginViewController.menuButtonForMapViewController = self.menuButton;
        facebookLoginViewController.myLocationButtonForMapViewController = self.myLocationButton;
        facebookLoginViewController.filterButtonForMapViewController = self.filterButton;
        facebookLoginViewController.refreshButtonForMapViewController = self.refreshButton;
        facebookLoginViewController.view.backgroundColor = [UIColor clearColor];
        [facebookLoginViewController setTransitioningDelegate:transitionController];
        facebookLoginViewController.modalPresentationStyle= UIModalPresentationCustom;
        [self presentViewController:facebookLoginViewController animated:YES completion:nil];
    } else {
        if([[PFInstallation currentInstallation] objectId]) {
            [[PFUser currentUser] setObject:[[PFInstallation currentInstallation] objectId] forKey:@"InstallationID"];
        }
        [self presentMenuBars];
    }
}

-(void)presentMenuBars
{
    CGRect topBarFrame = self.topBar.frame;
    CGRect searchBarFrame = self.searchBar.frame;
    CGRect bottomBarFrame = self.bottomBar.frame;
    CGRect menuButtonFrame = self.menuButton.frame;
    CGRect filterButtonFrame = self.filterButton.frame;
    CGRect refreshButtonFrame = self.refreshButton.frame;
    CGRect myLocationButtonFrame = self.myLocationButton.frame;
    CGRect profileImageButtonFrame = self.userProfileImageButton.frame;
    
    [UIView beginAnimations:@"show menu bars" context:nil];
    [UIView setAnimationDuration:.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    
    [self.topBar setFrame:CGRectMake(topBarFrame.origin.x, self.view.frame.origin.y, topBarFrame.size.width, topBarFrame.size.height)];
    [self.searchBar setFrame:CGRectMake(searchBarFrame.origin.x, 18.0, searchBarFrame.size.width, searchBarFrame.size.height)];
    [self.bottomBar setFrame:CGRectMake(bottomBarFrame.origin.x, self.view.frame.size.height-bottomBarFrame.size.height, bottomBarFrame.size.width, bottomBarFrame.size.height)];
    bottomBarFrame = self.bottomBar.frame;
    float newButtonYVal = bottomBarFrame.origin.y + 0.5*(bottomBarFrame.size.height - menuButtonFrame.size.height);
    [self.menuButton setFrame:CGRectMake(menuButtonFrame.origin.x, newButtonYVal, menuButtonFrame.size.width, menuButtonFrame.size.height)];
    [self.myLocationButton setFrame:CGRectMake(myLocationButtonFrame.origin.x, newButtonYVal, myLocationButtonFrame.size.width, myLocationButtonFrame.size.height)];
    [self.filterButton setFrame:CGRectMake(filterButtonFrame.origin.x, newButtonYVal, filterButtonFrame.size.width, filterButtonFrame.size.height)];
    [self.refreshButton setFrame:CGRectMake(refreshButtonFrame.origin.x, newButtonYVal, refreshButtonFrame.size.width, refreshButtonFrame.size.height)];
    [self.userProfileImageButton setFrame:CGRectMake(profileImageButtonFrame.origin.x, 20, profileImageButtonFrame.size.width, profileImageButtonFrame.size.height)];
    
    [UIView commitAnimations];
}

-(void)setGameSchedule
{
    self.gameSchedule = [[NSMutableArray alloc] init];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-08-30 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-09-06 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-09-13 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-09-27 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-10-04 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-10-11 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-10-18 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-10-25 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-11-01 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-11-08 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-11-15 23:59:59 CST"]];
    [self.gameSchedule addObject:[dateFormatter dateFromString: @"2014-11-27 23:59:59 CST"]];
}

-(void)fetchUTGames
{
    PFQuery *scheduleQuery = [PFQuery queryWithClassName:@"Games"];
    [scheduleQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (Game *game in objects) {
                //do stuff
            }
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

-(void)initializeFilterParameters
{
    self.pastDate = today;
    for (NSDate *date in self.gameSchedule) {
        if( [date timeIntervalSinceDate:today] > 0 ) {
            self.futureDate = date;
            break;
        }
    }
    self.showTailgates = YES;
    self.showAfterParties = YES;
    self.showWatchParties = YES;
    self.showRestaurants = YES;
    self.showEventsInMyPlaybookOnly = NO;
    self.radius = -1;
    [self setUpDateSliders];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    self.startDateLabel.text = @"Today";
    self.endDateLabel.text = [dateFormatter stringFromDate:self.futureDate];
}

- (IBAction) toggleTailgatesPressed:(UIButton *)sender
{
    if (tailgatesVisible) {
        for (Tailgate *tailgate in self.tailgates) {
            [[self.mapView viewForAnnotation: tailgate] setHidden: YES];
        }
        tailgatesVisible = NO;
    } else {
        for (Tailgate *tailgate in self.tailgates) {
            [[self.mapView viewForAnnotation: tailgate] setHidden: NO];
        }
        tailgatesVisible = YES;
    }
}

- (IBAction) toggleAfterPartiesPressed:(UIButton *)sender
{
    if (afterPartiesVisible) {
        for (AfterParty *afterParty in self.afterParties) {
            [[self.mapView viewForAnnotation: afterParty] setHidden: YES];
        }
        afterPartiesVisible = NO;
    } else {
        for (AfterParty *afterParty in self.afterParties) {
            [[self.mapView viewForAnnotation: afterParty] setHidden: NO];
        }
        afterPartiesVisible = YES;
    }
}

- (IBAction) toggleRestaurantsPressed:(UIButton *)sender
{
    if (restaurantsVisible) {
        for (Restaurant *restaurant in self.restaurants) {
            [[self.mapView viewForAnnotation: restaurant] setHidden: YES];
        }
        restaurantsVisible = NO;
    } else {
        for (Restaurant *restaurant in self.restaurants) {
            [[_mapView viewForAnnotation: restaurant] setHidden: NO];
        }
        restaurantsVisible = YES;
    }
}

-(void)setUpDateSliders
{
    NSMutableArray *dates = [[NSMutableArray alloc] init];
    [dates addObject:@"Today"];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    for (NSDate *date in self.gameSchedule) {
        [dates addObject:[dateFormatter stringFromDate:date]];
    }
    self.datesAsStrings = [NSArray arrayWithArray:dates];
    NSInteger numberOfOptions = ((float)[self.datesAsStrings count] - 1);
    self.startDateSlider.maximumValue = numberOfOptions;
    self.startDateSlider.minimumValue = 0;
    self.endDateSlider.maximumValue = numberOfOptions;
    self.endDateSlider.minimumValue = 0;
    self.startDateSlider.continuous = NO;
    [self.startDateSlider addTarget:self
               action:@selector(valueChanged:)
     forControlEvents:UIControlEventValueChanged];
    self.endDateSlider.continuous = NO;
    [self.endDateSlider addTarget:self
                             action:@selector(valueChanged:)
                   forControlEvents:UIControlEventValueChanged];
}

- (void)valueChanged:(UISlider *)sender {
   //IMPLEMENT HIDING PINS AFTER SLIDER HERE
    NSUInteger index = (NSUInteger)(sender.value + 0.5);
    [sender setValue:index animated:NO];
    NSString *date = self.datesAsStrings[index];
    if (sender == self.startDateSlider) {
        self.startDateLabel.text = date;
    } else {
        self.endDateLabel.text = date;
    }
    [self applyDateFilterWithStartDate:self.startDateLabel.text WithEndDate:self.endDateLabel.text];
}

//This could be refactored. Hardly sticks to the single responsibility principle
-(void)applyDateFilterWithStartDate:(NSString *)startDate WithEndDate:(NSString *)endDate
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateStyle = NSDateFormatterShortStyle;
    NSDate *start = [[NSDate alloc] init];
    NSDate *end = [[NSDate alloc] init];
    start = [dateFormatter dateFromString:startDate];
    end = [dateFormatter dateFromString:endDate];
    for (Tailgate *tailgate in self.tailgates) {
        if([tailgate.startTime timeIntervalSinceDate:start] > 0) {
            [[self.mapView viewForAnnotation: tailgate] setHidden: YES];
        } else {
            [[self.mapView viewForAnnotation: tailgate] setHidden: NO];
        }
        if([tailgate.endTime timeIntervalSinceDate:end] > 0) {
            [[self.mapView viewForAnnotation: tailgate] setHidden: YES];
        } else {
            [[self.mapView viewForAnnotation: tailgate] setHidden: NO];
        }
    }
}

#pragma mark - User Location

- (void)setUpLocationManager
{
    userLocationUpdatedOnce = NO;
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if(!(userLocationUpdatedOnce)) {
        [self setUpMapRegionWithoutUserLocationData];
    }
}

// handling the user's choice whether or not to allow us to use their location
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied) {
        [self setUpMapRegionWithoutUserLocationData];
    }
    else if (status == kCLAuthorizationStatusAuthorized) {
        userAllowedLocationTracking = YES;
    }
}

// this is called as soon as we have a lock on user location
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    self.currentLocation = [locations lastObject];
    if(!(userLocationUpdatedOnce)) {
        [self zoomInOnUserLocation];
        userLocationUpdatedOnce = YES;
    }
    if (timeInSecondsSinceLocationSavedInParse > 60) {
        PFGeoPoint *userLocation = [PFGeoPoint geoPointWithLocation:self.currentLocation];
        [[PFUser currentUser] setObject:userLocation forKey:@"userLocation"];
        [[PFUser currentUser] saveInBackground];
        timeInSecondsSinceLocationSavedInParse = 0;
    }
    timeInSecondsSinceLocationSavedInParse++;
}

-(void)setUpMapRegionWithoutUserLocationData
{
    userAllowedLocationTracking = NO;
    // If user doesn't allow location permissions, then just zoom in on Bob Bullock
    MKCoordinateRegion myRegion;
    CLLocationCoordinate2D center;
    center.latitude = BB_LAT;
    center.longitude = BB_LONG;
    MKCoordinateSpan span;
    span.latitudeDelta = ZOOM;
    span.longitudeDelta = ZOOM;
    myRegion.center = center;
    myRegion.span = span;
    [self.mapView setRegion:myRegion animated:YES];
}

-(void)zoomInOnUserLocation
{
    MKCoordinateRegion myRegion;
    CLLocationCoordinate2D center;
    center.latitude = self.currentLocation.coordinate.latitude;
    center.longitude = self.currentLocation.coordinate.longitude;
    MKCoordinateSpan span;
    span.latitudeDelta = ZOOM;
    span.longitudeDelta = ZOOM;
    myRegion.center = center;
    myRegion.span = span;
    [self.mapView setRegion:myRegion animated:YES];
    [self.mapView setShowsUserLocation:YES];
}

#pragma mark - Bottom Bar Buttons

- (IBAction) showMenuPressed:(UIButton *)sender
{
    [self.bottomBarMenu toggleMenu];
}

-(void) initializeMenus
{
    UzysSMMenuItem *item0 = [[UzysSMMenuItem alloc] initWithTitle:@"Add Event" image:[UIImage imageNamed:@"plus.png"] action:^(UzysSMMenuItem *item) {
        // implement adding an event here
        EditEventVC *editVC = [[EditEventVC alloc] initWithNibName:@"EditEventVC" bundle:nil];
        editVC.mainMap = self.mapView;
        [self presentModalViewController:editVC animated:YES];
    }];
    
    UzysSMMenuItem *item1 = [[UzysSMMenuItem alloc] initWithTitle:@"Settings" image:[UIImage imageNamed:@"gear.png"] action:^(UzysSMMenuItem *item) {
        // present settings view controller here
    }];
    UzysSMMenuItem *item2 = [[UzysSMMenuItem alloc] initWithTitle:@"FAQ" image:[UIImage imageNamed:@"question-mark.png"] action:^(UzysSMMenuItem *item) {
        // present FAQ view controller here (probably best to do a UIWebView and put this online for ease of updating)
    }];
    item0.tag = 0;
    item1.tag = 1;
    item2.tag = 2;
    
    NSInteger contentAboveHeight = self.view.frame.size.height-(3.0*45.0+44.0); //height of three menu items and our bottom bar
    
    self.bottomBarMenu = [[UzysSlideMenu alloc] initWithItems:@[item0,item1,item2]];
    self.bottomBarMenu.frame = CGRectMake(self.bottomBarMenu.frame.origin.x, self.bottomBarMenu.frame.origin.y+ contentAboveHeight, self.bottomBarMenu.frame.size.width, self.bottomBarMenu.frame.size.height);
    
    [self.view addSubview:self.bottomBarMenu];
}

- (IBAction) myLocationPressed:(UIButton *)sender
{
    [self zoomInOnUserLocation];
}

-(IBAction)filterButtonPressed:(UIButton *)sender
{
    [self toggleFilterView];
}

-(void)toggleFilterView
{
    CGRect filterFrame = self.filterView.frame;
    CGRect frame = self.view.frame;
    CGRect menuBarFrame = self.bottomBar.frame;
    [UIView beginAnimations:@"raise filterView!" context:nil];
    [UIView setAnimationDuration:.5];
    [UIView setAnimationBeginsFromCurrentState:YES];
    if (filterFrame.origin.y < self.view.frame.size.height) {
        [self.filterView setFrame:CGRectMake(filterFrame.origin.x, frame.size.height, filterFrame.size.width, filterFrame.size.height)];
    } else {
        [self.filterView setFrame:CGRectMake(filterFrame.origin.x, frame.size.height-(menuBarFrame.size.height+filterFrame.size.height), filterFrame.size.width, filterFrame.size.height)];
    }
    [UIView commitAnimations];
}

#pragma mark - Map Functions

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    // If the annotation is the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    // Handle any custom annotations.
    NSString *eventType = [NSStringFromClass([annotation class]) lowercaseString];
    
    // Try to dequeue an existing pin view first.
    MKAnnotationView* pinView = (MKAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:eventType];
    if (!pinView)
    {
        // If an existing pin view was not available, create one.
        pinView = [[MKAnnotationView alloc] initWithAnnotation:annotation
                                               reuseIdentifier:eventType];
        pinView.image = [UIImage imageNamed:[NSString stringWithFormat:@"%@-pin.png", eventType]];
        pinView.canShowCallout = YES;
    } else {
        pinView.annotation = annotation;
    }
    
    return pinView;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    self.event = nil;
    if(![view.annotation isKindOfClass:[MKUserLocation class]]) {
        self.event = view.annotation;
        UIButton *disclosure = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        [disclosure addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showMoreInfoForEvent)]];
        view.rightCalloutAccessoryView = disclosure;
    }
}

- (void)showMoreInfoForEvent
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    GPEventDetailViewController *eventDetailViewController = [storyboard instantiateViewControllerWithIdentifier:@"event-details"];

    eventDetailViewController.event = self.event;
    eventDetailViewController.eventType = NSStringFromClass([self.event class]);
    eventDetailViewController.view.backgroundColor = [UIColor lightGrayColor];
    [eventDetailViewController setTransitioningDelegate:transitionController];
    eventDetailViewController.modalPresentationStyle= UIModalPresentationCustom;
    [self presentViewController:eventDetailViewController animated:YES completion:nil];
}


- (void)loadEventPins
{
    [self loadTailgatePins];
    [self loadAfterPartyPins];
    [self loadWatchPartyPins];
    [self loadRestaurantPins];
}

- (void)loadTailgatePins
{
    self.tailgates = [[NSMutableArray alloc] init];
    PFQuery *tailgateQuery = [PFQuery queryWithClassName:@"Tailgate"];
    [tailgateQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (Tailgate *tailgate in objects) {
                [self.mapView addAnnotation:tailgate];
                [self.tailgates addObject:tailgate];
            }
            tailgatesVisible = YES;
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

- (void)loadAfterPartyPins
{
    self.afterParties = [[NSMutableArray alloc] init];
    PFQuery *afterPartyQuery = [PFQuery queryWithClassName:@"AfterParty"];
    [afterPartyQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (AfterParty *afterParty in objects) {
                [self.mapView addAnnotation:afterParty];
                [self.afterParties addObject:afterParty];
            }
            afterPartiesVisible = YES;
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

- (void)loadWatchPartyPins
{
    self.watchParties = [[NSMutableArray alloc] init];
    PFQuery *watchPartyQuery = [PFQuery queryWithClassName:@"WatchParty"];
    [watchPartyQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (WatchParty *watchParty in objects) {
                [self.mapView addAnnotation:watchParty];
                [self.watchParties addObject:watchParty];
            }
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

- (void)loadRestaurantPins
{
    self.restaurants = [[NSMutableArray alloc] init];
    PFQuery *restaurantQuery = [PFQuery queryWithClassName:@"Restaurant"];
    [restaurantQuery findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (!error) {
            for (Restaurant *restaurant in objects) {
                [self.mapView addAnnotation:restaurant];
                [self.restaurants addObject:restaurant];
            }
            restaurantsVisible = YES;
        } else {
            // Log details of the failure
            NSLog(@"Error: %@ %@", error, [error userInfo]);
        }
    }];
}

#pragma mark - User Profile Photo Button

- (IBAction) userProfilePicturePressed:(UIButton *)sender
{
    [self.view endEditing:YES];
    [self.frostedViewController.view endEditing:YES];
    self.frostedViewController.direction = REFrostedViewControllerDirectionRight;

    [self.frostedViewController presentMenuViewController];
}

-(void) setProfilePhoto
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [self.userProfileImageButton.layer setCornerRadius:self.userProfileImageButton.frame.size.width/2];
    self.userProfileImageButton.layer.masksToBounds = YES;
    UIImage *userProfileImage;
    if([defaults objectForKey:@"pictureURL"]!=nil) {
        userProfileImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[defaults objectForKey:@"pictureURL"]]]];
    } else {
        userProfileImage = [UIImage imageNamed:@"default_profile.jpg"];
    }
    [self.userProfileImageButton setBackgroundImage:userProfileImage forState:UIControlStateNormal];
}

@end
