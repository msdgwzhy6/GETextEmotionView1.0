//
//  GETextEmotionView.m
//  CBEmotionView
//
//  Created by sunyanliang on 13-9-7.
//  Copyright (c) 2013年. All rights reserved.
//

#import "GETextEmotionView.h"

static NSString* kTextKey = @"kTextKey";
static NSString* kEmotionImageKey = @"kEmotionImageKey";


@interface GETextEmotionView ()
{
    float _oneHanZiWidth;
    float _oneHanZiHeight;
    float _maxWidth;
}
@property (copy, nonatomic) NSString* pattern;
@property (strong, nonatomic) NSDictionary* textAttributes;

//表情文字分离程序
-(NSArray*)sectionsAfterAnalyzeString:(NSString*)string withPattern:(NSString*)pattern;

//文本行折行分析后，第一项为绘图起始点，第二项为文本,第三项为下一次绘图的起始点的X落点
-(NSArray*)textRowsFromPoint:(CGPoint)point text:(NSString*)text;

@end


@implementation GETextEmotionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        self.pattern = @"\\[(\\w){1,4}]";//以“[]”标识表情文字
        _rowInterval = 0.0f;
        self.emotionString = @"";//default value
        self.font = [UIFont fontWithName:@"Helvetica-light" size:15.0];
        self.textColor = [UIColor blackColor];
        self.heightAutosizing = YES;
    }
    return self;
}

-(void)willMoveToSuperview:(UIView *)newSuperview
{
    if (self.superview == nil) {
        self.textAttributes = @{NSFontAttributeName:self.font,NSForegroundColorAttributeName:self.textColor,};
        NSString* oneHanZi = @"字";//表情是一个汉字高度
        _oneHanZiWidth = [oneHanZi sizeWithAttributes:self.textAttributes].width;
        _oneHanZiHeight = [oneHanZi sizeWithAttributes:self.textAttributes].height;
        _maxWidth = self.bounds.size.width;
    }
}

-(void)setEmotionString:(NSString *)emotionString
{
    NSString* temp = [emotionString copy];
    _emotionString = temp;
    if (self.superview) {
        if (self.heightAutosizing == YES) {
            [self sizeToFit];
        }
        [self setNeedsDisplay];
    }
    
}

-(void)sizeToFit
{
    CGSize size = [self.emotionString sizeWithAttributes:self.textAttributes];
    NSInteger rowCount = ceilf(size.width / _maxWidth);
    CGRect frame = self.frame;
    frame.size.height = (rowCount + 1) * (_oneHanZiHeight + _rowInterval);
    self.frame = frame;
}

//表情与文本分离，按次序存储于数组里，以供 -drawRect: 依次画出
-(NSArray*)sectionsAfterAnalyzeString:(NSString*)string withPattern:(NSString*)pattern
{
    NSMutableArray* sections = [NSMutableArray array];
    NSError *error = nil;
    NSRegularExpression *regExp = [[NSRegularExpression alloc] initWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
    while (1) {
        
        NSRange range = [regExp rangeOfFirstMatchInString:string options:NSMatchingReportCompletion range:NSMakeRange(0, string.length)];
        
        if (range.location == NSNotFound) {
            [sections addObject:@{kTextKey:string}];
            break;
        }else{
            
            NSString* text = [string substringToIndex:range.location];
            if (text) {
                [sections addObject:@{kTextKey:text}];
            }
            
            NSString* emotionString = [string substringWithRange:NSMakeRange(range.location+1, range.length - 2)];
            if (emotionString) {
                NSString* emotionPath = [[NSBundle mainBundle] pathForResource:emotionString ofType:@"png"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:emotionPath]) {
                    [sections addObject:@{kEmotionImageKey:emotionString}];
                }else{
                    [sections addObject:@{kTextKey:[string substringWithRange:range]}];
                }
            }
            
            string = [string substringFromIndex:range.location+ range.length];//越界返回空字符串，不是nil
            
            if (string.length == 0) {
                break;
            }
        }
        
    }//while end
    return sections;
}

//文本行折行分析后，第一项为绘图起始点，第二项为文本,第三项为下一次绘图的起始点的X落点
-(NSArray*)textRowsFromPoint:(CGPoint)point text:(NSString*)text
{
    NSMutableArray* textRows = [NSMutableArray array];
    
    CGSize size = [text sizeWithAttributes:_textAttributes];

    if (point.x + size.width <= _maxWidth) {//一行容得下
        [textRows addObject:@[[NSValue valueWithCGPoint:point],text,[NSNumber numberWithFloat:point.x + size.width]]];
    }else{
        float remainWidth = _maxWidth - point.x;
        NSInteger remainWordCount = remainWidth / _oneHanZiWidth;
        NSString* subText = [text substringToIndex:remainWordCount];
        CGSize sizeSubText = [subText sizeWithAttributes:_textAttributes];
        [textRows addObject:@[[NSValue valueWithCGPoint:point],subText,[NSNumber numberWithFloat:point.x + sizeSubText.width]]];
        text = [text substringFromIndex:remainWordCount];
        [textRows addObjectsFromArray:[self textRowsFromPoint:CGPointMake(0, point.y + _oneHanZiHeight + _rowInterval) text:text]];
    }
    return textRows;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    __block CGPoint point = CGPointZero;
    
    NSArray* sections = [self sectionsAfterAnalyzeString:self.emotionString withPattern:self.pattern];
    for (NSDictionary* aSection in sections) {
        
        [aSection enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSString* textOrImageName = obj;
            if (key == kTextKey) {
                NSArray* textRows = [self textRowsFromPoint:point text:textOrImageName];
                for (NSArray* aTextRow in textRows) {
                    
                    CGPoint pointOneRow = [[aTextRow objectAtIndex:0] CGPointValue];
                    NSString* textOneRow = [aTextRow objectAtIndex:1];
                    [textOneRow drawAtPoint:pointOneRow withAttributes:_textAttributes];
                    point.x = [[aTextRow objectAtIndex:2] floatValue];
                    
                }
                
                point.y += (textRows.count - 1) * (_oneHanZiHeight + _rowInterval);
                
            }else if(key == kEmotionImageKey){
                if (point.x + _oneHanZiWidth > _maxWidth) {//换行判断
                    point.y += _oneHanZiHeight + _rowInterval;
                    point.x = 0;
                }
                UIImage* image = [UIImage imageNamed:textOrImageName];
                [image drawInRect:CGRectMake(point.x, point.y, _oneHanZiHeight, _oneHanZiHeight)];//表情正方形
                point.x += _oneHanZiHeight+2;
            }
        }];
    }//end for
}

@end
