//
//  EasyShowAlertView.m
//  EasyShowViewDemo
//
//  Created by nf on 2017/12/14.
//  Copyright © 2017年 chenliangloveyou. All rights reserved.
//

#import "EasyShowAlertView.h"
#import "UIView+EasyShowExt.h"

@interface EasyShowAlertItem : NSObject
@property (nonatomic,strong)NSString *title ;
@property (nonatomic,assign)ShowAlertItemType itemTpye ;
@property (nonatomic,strong)alertItemCallback callback ;
@end
@implementation EasyShowAlertItem
@end


@interface EasyAlertLabel :UILabel
- (instancetype)initWithContentInset:(UIEdgeInsets)contentInset ;
@property (nonatomic) UIEdgeInsets contentInset;
@end

@implementation EasyAlertLabel
- (instancetype)initWithContentInset:(UIEdgeInsets)contentInset
{
    if (self = [super init]) {
        _contentInset = contentInset ;
    }
    return self ;
}
- (void)setContentInset:(UIEdgeInsets)contentInset {
    _contentInset = contentInset;
    NSString *tempString = self.text;
    self.text = @"";
    self.text = tempString;
}
- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines
{
    UIEdgeInsets insets = self.contentInset;
    CGRect rect = [super textRectForBounds:UIEdgeInsetsInsetRect(bounds, insets)
                    limitedToNumberOfLines:numberOfLines];
    
    rect.origin.x    -= insets.left;
    rect.origin.y    -= insets.top;
    rect.size.width  += (insets.left + insets.right);
    rect.size.height += (insets.top + insets.bottom);
    
    return rect;
}

-(void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, self.contentInset)];
}
@end


typedef NS_ENUM(NSUInteger , alertShowType) {
    alertShowTypeAlert ,
    alertShowTypeActionSheet ,
};


@interface EasyShowAlertView()<CAAnimationDelegate>

@property (nonatomic,assign)alertShowType alertShowType ;

@property (nonatomic,strong)UILabel *alertTitleLabel ;
@property (nonatomic,strong)UILabel *alertMessageLabel ;
@property (nonatomic,strong)NSMutableArray<EasyShowAlertItem *> *alertItemArray ;
@property (nonatomic,strong)NSMutableArray *alertButtonArray ;

@property (nonatomic,strong)UIWindow *alertWindow ;
@property (nonatomic,strong)UIView *alertBgView ;
@property (nonatomic,strong)UIWindow *oldKeyWindow ;

@end

@implementation EasyShowAlertView


+ (instancetype)showActionSheetWithTitle:(NSString *)title message:(NSString *)message
{
    return [self showAlertWithType:alertShowTypeActionSheet title:title message:message];
}
+ (instancetype)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    return [self showAlertWithType:alertShowTypeAlert title:title message:message];
}
+ (instancetype)showAlertWithType:(alertShowType)type title:(NSString *)title message:(NSString *)message
{
    if (ISEMPTY(title) && ISEMPTY(message)) {
        NSAssert(NO, @"you should set title or message") ;
        return nil;
    }
    EasyShowAlertView *showView = [[EasyShowAlertView alloc]initWithFrame:[UIScreen mainScreen].bounds];
    showView.alertTitleLabel.text = title ;
    showView.alertMessageLabel.text = message ;
    showView.alertShowType = type ;
    showView.alertItemArray = [NSMutableArray arrayWithCapacity:3];
    return showView ;
}
- (void)addItemWithTitle:(NSString *)title itemType:(ShowAlertItemType)itemType callback:(alertItemCallback)callback
{
    EasyShowAlertItem *item = [[EasyShowAlertItem alloc]init];
    item.title = title ;
    item.itemTpye = itemType ;
    item.callback = callback ;
    [self.alertItemArray addObject:item];
}
- (void)show
{
    self.oldKeyWindow = [UIApplication sharedApplication].keyWindow ;
    [self.oldKeyWindow resignKeyWindow];
    [self.alertWindow addSubview:self];
    [self.alertWindow makeKeyWindow];
    
    [self addSubview:self.alertBgView];
    
    [self.alertBgView addSubview:self.alertTitleLabel];
    [self.alertBgView addSubview:self.alertMessageLabel];
    for (int i = 0; i < self.alertItemArray.count; i++) {
        UIButton *button = [self alertButtonWithIndex:i ];
        [self.alertBgView addSubview:button];
    }
    
    [self layoutAlertSubViews];
   
    [self showStartAnimationWithType:self.options.alertAnimationType completion:nil];

}
- (void)showEndAnimationWithType:(alertAnimationType)type completion:(void(^)(void))completion
{
    switch (type) {
        case alertAnimationTypeFade:
        {
            [UIView animateWithDuration:self.options.showAnimationTime
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                                 self.alpha = .0f;
                                 self.transform = CGAffineTransformIdentity;
                             } completion:^(BOOL finished) {
                                 if (completion) {
                                     completion() ;
                                 }
                             }];
        }break;
        case alertAnimationTypeZoom:
        {
            self.alpha = 0 ;
            self.transform = CGAffineTransformConcat(CGAffineTransformIdentity, CGAffineTransformMakeScale(0.5f, 0.5f));

            [UIView animateWithDuration:self.options.showAnimationTime
                             animations:^{
                                 self.alpha = 1.0f;
                                 self.transform = CGAffineTransformIdentity;
                             } completion:^(BOOL finished) {
                                 if (completion) {
                                     completion() ;
                                 }
                             }];
        }break ;
        case alertAnimationTypeBounce:
        {
            CABasicAnimation *bacAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            bacAnimation.duration = self.options.showAnimationTime ;
            bacAnimation.beginTime = .0;
            bacAnimation.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.4f :0.3f :0.5f :-0.5f];
            bacAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
            bacAnimation.toValue = [NSNumber numberWithFloat:0.0f];
            
            CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
            animationGroup.animations = @[bacAnimation];
            animationGroup.duration =  bacAnimation.duration;
            animationGroup.removedOnCompletion = NO;
            animationGroup.fillMode = kCAFillModeForwards;
            
            animationGroup.delegate = self ;
            [animationGroup setValue:completion forKey:@"handler"];

            [self.alertBgView.layer addAnimation:animationGroup forKey:nil];
        }break ;
            
        default:
        {
            if (completion) {
                completion();
            }
        }
            break;
    }
}
#pragma mark - CAAnimation delegate

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    void(^completion)(void) = [anim valueForKey:@"handler"];
    if (completion) {
        completion();
    }
}
- (void)showStartAnimationWithType:(alertAnimationType)type completion:(void(^)(void))completion
{
    switch (type) {
        case alertAnimationTypeFade:
        {
            self.alertBgView.alpha = 0 ;
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:self.options.showAnimationTime];
            self.alertBgView.alpha = 1.0f;
            [UIView commitAnimations];
        }break;
        case alertAnimationTypeZoom:
        {
            self.alertBgView.alpha = 0 ;
            self.alertBgView.transform = CGAffineTransformConcat(CGAffineTransformIdentity, CGAffineTransformMakeScale(3, 3));
            [UIView beginAnimations:nil context:NULL];
            [UIView setAnimationDuration:self.options.showAnimationTime];
            self.alertBgView.alpha = 1.0f;
                self.alertBgView.transform = CGAffineTransformIdentity;
            [UIView commitAnimations];
        }break ;
        case alertAnimationTypeBounce:
        {
            CAKeyframeAnimation *popAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
            popAnimation.duration = self.options.showAnimationTime;
            popAnimation.values = @[[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.01f, 0.01f, 1.0f)],
                                    [NSValue valueWithCATransform3D:CATransform3DMakeScale(1.05f, 1.05f, 1.0f)],
                                    [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.95f, 0.95f, 1.0f)],
                                    [NSValue valueWithCATransform3D:CATransform3DIdentity]];
            popAnimation.keyTimes = @[@0.2f, @0.5f, @0.75f, @1.0f];
            popAnimation.timingFunctions = @[[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                             [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                                             [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [self.alertBgView.layer addAnimation:popAnimation forKey:nil];
        }break ;
            
        default:
            break;
    }
}

- (void)layoutAlertSubViews
{
    CGFloat bgViewMaxWidth = self.alertShowType==alertShowTypeAlert ?  SCREEN_WIDTH*0.75 : SCREEN_WIDTH ;
    CGFloat buttonHeight = 50 ;
    
    CGSize titleLabelSize = [self.alertTitleLabel sizeThatFits:CGSizeMake(bgViewMaxWidth, MAXFLOAT)];
    if (ISEMPTY(self.alertTitleLabel.text)) {
        titleLabelSize.height = 10 ;
    }
    self.alertTitleLabel.frame = CGRectMake(0, 0, bgViewMaxWidth, titleLabelSize.height);
    
    CGSize messageLabelSize = [self.alertMessageLabel sizeThatFits:CGSizeMake(bgViewMaxWidth, MAXFLOAT)];
    if (ISEMPTY(self.alertMessageLabel.text)) {
        messageLabelSize.height = 10 ;
    }
    self.alertMessageLabel.frame = CGRectMake(0, self.alertTitleLabel.bottom, bgViewMaxWidth, messageLabelSize.height) ;
    
    CGFloat totalHeight = self.alertMessageLabel.bottom + 0.5 ;
    CGFloat btnCount = self.alertButtonArray.count ;
    
    if (self.alertShowType==alertShowTypeAlert && btnCount==2 && self.options.alertTowItemHorizontal) {
       
        for (int i = 0; i < btnCount ; i++) {
            UIButton *tempButton = self.alertButtonArray[i];
            
            CGFloat tempButtonX = i ? (bgViewMaxWidth/2+0.5) : 0 ;
            CGFloat tempButtonY = self.alertMessageLabel.bottom +0.5  ;
            [tempButton setFrame:CGRectMake(tempButtonX, tempButtonY, bgViewMaxWidth/2, buttonHeight)];
            totalHeight = tempButton.bottom ;
        }
    }
    else{
        for (int i = 0; i < btnCount ; i++) {
            UIButton *tempButton = self.alertButtonArray[i];
            
            CGFloat lineHeight = ((i==btnCount-1)&&self.alertShowType==alertShowTypeActionSheet) ? 10 : 0.5 ;
            CGFloat tempButtonY = self.alertMessageLabel.bottom + lineHeight + i*(buttonHeight+ 0.5) ;
            [tempButton setFrame:CGRectMake(0, tempButtonY, bgViewMaxWidth, buttonHeight)];
            totalHeight = tempButton.bottom ;
        }
    }
 
    self.alertBgView.bounds = CGRectMake(0, 0, bgViewMaxWidth, totalHeight);
    
    if (self.alertShowType == alertShowTypeAlert) {
        self.alertBgView.center = self.center ;
        
        UIColor *boderColor = [[UIColor lightGrayColor]colorWithAlphaComponent:0.3];
        [self.alertBgView setRoundedCorners:UIRectCornerAllCorners
                                borderWidth:1
                                borderColor:boderColor
                                 cornerSize:CGSizeMake(15,15)];//需要添加阴影
    }else{
        self.alertBgView.center = CGPointMake(SCREEN_WIDTH/2, SCREEN_HEIGHT-(totalHeight/2));
    }
    

    
}

- (void)bgViewTap:(UIPanGestureRecognizer *)recognizer
{
    
}
- (void)bgViewPan:(UIPanGestureRecognizer *)recognizer
{
  
    CGPoint location = [recognizer locationInView:self];

    UIButton *tempButton = nil;
    for (int i = 0; i < self.alertButtonArray.count; i++) {
        UIButton *itemBtn = self.alertButtonArray[i];
        CGRect btnFrame = [itemBtn convertRect:itemBtn.bounds toView:self];
        if (CGRectContainsPoint(btnFrame, location)) {
            itemBtn.highlighted = YES;
            tempButton = itemBtn;
        } else {
            itemBtn.highlighted = NO;
        }
    }
    
    if (tempButton && recognizer.state == UIGestureRecognizerStateEnded) {
        [self buttonClick:tempButton];
    }
    
}

- (void)buttonClick:(UIButton *)button
{
    EasyShowAlertItem *item = self.alertItemArray[button.tag];
    if (item.callback) {
        item.callback(self);
    }
    [self alertWindowTap];
}
- (UIView *)alertBgView
{
    if (nil == _alertBgView) {
        _alertBgView = [[UIView alloc]init];
        if (self.options.alertBackgroundColor) {
            _alertBgView.backgroundColor = self.options.alertBackgroundColor;
        }else{
            _alertBgView.backgroundColor = [UIColor groupTableViewBackgroundColor];
        }
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(bgViewPan:)] ;
        [_alertBgView addGestureRecognizer:panGesture];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(bgViewTap:)] ;
        [_alertBgView addGestureRecognizer:tapGesture];

        //        _alertBgView.clipsToBounds = YES ;
        //        _alertBgView.layer.cornerRadius = 10 ;
    }
    return _alertBgView ;
}
- (NSMutableArray *)alertButtonArray
{
    if (nil == _alertButtonArray) {
        _alertButtonArray = [NSMutableArray arrayWithCapacity:3];
    }
    return _alertButtonArray ;
}
- (UILabel *)alertTitleLabel
{
    if (nil == _alertTitleLabel) {
        _alertTitleLabel = [[EasyAlertLabel alloc] initWithContentInset:UIEdgeInsetsMake(35, 30, 15, 30)];
        _alertTitleLabel.textAlignment = NSTextAlignmentCenter;
        if (self.options.alertBackgroundColor) {
            _alertTitleLabel.backgroundColor = self.options.alertBackgroundColor;
        }
        else{
            _alertTitleLabel.backgroundColor = [UIColor whiteColor];
        }
        _alertTitleLabel.font = [UIFont boldSystemFontOfSize:20];
        //        _alertTitleLabel.textColor = [UIColor yellowColor];
        _alertTitleLabel.numberOfLines = 0;
    }
    return _alertTitleLabel ;
}
- (UILabel *)alertMessageLabel
{
    if (nil == _alertMessageLabel) {
        _alertMessageLabel = [[EasyAlertLabel alloc] initWithContentInset:UIEdgeInsetsMake(15, 30, 20, 30)];
        _alertMessageLabel.textAlignment = NSTextAlignmentCenter;
        if (self.options.alertBackgroundColor) {
            _alertMessageLabel.backgroundColor = self.options.alertBackgroundColor;
        }
        else{
            _alertMessageLabel.backgroundColor = [UIColor whiteColor];
        }
        _alertMessageLabel.font = [UIFont systemFontOfSize:17];
        _alertMessageLabel.textColor = [UIColor grayColor];
        _alertMessageLabel.numberOfLines = 0;
    }
    return _alertMessageLabel ;
}
- (UIButton *)alertButtonWithIndex:(long)index
{
    EasyShowAlertItem *item = self.alertItemArray[index];
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.tag = index;
    button.adjustsImageWhenHighlighted = NO;
    [button setTitle:item.title forState:UIControlStateNormal];
    [button addTarget:self action:@selector(buttonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIImage *bgImage = [EasyShowUtils imageWithColor:[UIColor whiteColor]];
    UIImage *bgHighImage = [EasyShowUtils imageWithColor:[[UIColor whiteColor]colorWithAlphaComponent:0.7] ];
    [button setBackgroundImage:bgImage forState:UIControlStateNormal];
    [button setBackgroundImage:bgHighImage forState:UIControlStateHighlighted];
    
    UIFont *textFont = [UIFont systemFontOfSize:17] ;
    UIColor *textColor = [UIColor blackColor] ;
    switch (item.itemTpye) {
        case ShowAlertItemTypeRed: {
            textColor = [UIColor redColor];
        }break ;
        case ShowAlertItemTypeBlodRed:{
            textColor = [UIColor redColor];
            textFont  = [UIFont boldSystemFontOfSize:17] ;
        }break ;
        case ShowAlertItemTypeBlue:{
            textColor = [UIColor blueColor];
        }break ;
        case ShowAlertItemTypeBlodBlue:{
            textColor = [UIColor blueColor];
            textFont = [UIFont boldSystemFontOfSize:17] ;
        }break ;
        case ShowAlertItemTypeBlack:{
            
        }break ;
        case ShowAlertItemTypeBlodBlack:{
            textFont = [UIFont boldSystemFontOfSize:17] ;
        }break ;
        case ShowStatusTextTypeCustom:{
            
        }break ;
    }
    [button setTitleColor:textColor forState:UIControlStateNormal];
    [button setTitleColor:[textColor colorWithAlphaComponent:0.2] forState:UIControlStateHighlighted];
    [button.titleLabel setFont:textFont] ;
    
    [self.alertButtonArray addObject:button];
    
    return button ;
}
- (UIWindow *)alertWindow {
    if (nil == _alertWindow) {
        _alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        UITapGestureRecognizer *tapGes = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(alertWindowTap)];
        [_alertWindow addGestureRecognizer:tapGes];
        _alertWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
        _alertWindow.hidden = NO ;
    }
    
    return _alertWindow;
}
- (void)alertWindowTap
{
    
    void (^completion)(void) = ^{
        [self.oldKeyWindow makeKeyWindow];
        [self.alertWindow resignKeyWindow];
        [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self removeFromSuperview];
        
        [self.alertWindow.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.alertWindow.hidden = YES ;
        [self.alertWindow removeFromSuperview];
        self.alertWindow = nil;
    };
    
    [self showEndAnimationWithType:self.options.alertAnimationType
                        completion:completion];
   
    
}












//+ (void)showAlertSystemWithTitle:(NSString *)title
//                            desc:(NSString *)desc
//                     buttonArray:(NSArray *)buttonArray
//                        callBack:(showAlertCallback)callback
//{
//
//
//    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
//
//        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:desc preferredStyle:UIAlertControllerStyleActionSheet];
//
//        [buttonArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//            NSString *tempTitle = (NSString *)obj ;
//
//            UIAlertActionStyle showStyle = UIAlertActionStyleDefault ;
//            if (idx == 0) {
//                showStyle = UIAlertActionStyleDestructive ;
//            }
//            else if (idx == 1){
//                showStyle = UIAlertActionStyleCancel ;
//            }
//            UIAlertAction *action = [UIAlertAction actionWithTitle:tempTitle style:showStyle handler:^(UIAlertAction *action){
//                dispatch_after(0.2, dispatch_get_main_queue(), ^{
////                    if (sure) sure() ;
//                    [alertController dismissViewControllerAnimated:YES completion:nil];
//                });
//            }];
//            [alertController addAction:action];
//
//        }];
//
//
////        UIAlertAction *action2 = [UIAlertAction actionWithTitle:cancelTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
////
////            dispatch_after(0.2, dispatch_get_main_queue(), ^{
////                if (cancel)  cancel() ;
////                [alertController dismissViewControllerAnimated:YES completion:nil];
////            });
////        }];
////        [alertController addAction:action2];
//        [kTopViewController presentViewController:alertController animated:YES completion:nil];
//    }
//    else{
//
////        if (ISEMPTY(sureTitle)) {
////
////            _alertMessageCancel = cancel ;
////            UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:title message:contentMessage delegate:self cancelButtonTitle:cancelTitle otherButtonTitles:nil];
////            [alertView show];
////        }
////        else{
////
////            _alertMessageSure = sure ;
////            _alertMessageCancel = cancel ;
////            UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:title message:contentMessage delegate:self cancelButtonTitle:cancelTitle otherButtonTitles:sureTitle, nil];
////            [alertView show];
////        }
//    }
//
//}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    //    if (buttonIndex == 0) {
    //        if(_alertMessageCancel) _alertMessageCancel() ;
    //    }
    //    else if (buttonIndex == 1){
    //        if(_alertMessageSure) _alertMessageSure() ;
    //    }
}

@end