//
//  AssetLoaderDelegate.m
//  RCTVideo
//
//  Created by Kranthi Kumar on 09/05/18.
//  Copyright © 2018 Facebook. All rights reserved.
//

#import "AssetLoaderDelegate.h"


NSString* const URL_SCHEME_NAME = @"skd";

@implementation AssetLoaderDelegate
{
    NSString * _customData;
}

- (id)init
{
    self = [super init];
    return self;
}

- (void)setCustomData:(NSString*)customData
{
    _customData = customData;
}

- (NSData *)getContentKeyAndLeaseExpiryfromKeyServerModuleWithRequest:(NSData *)requestBytes contentIdentifierHost:(NSString *)assetStr leaseExpiryDuration:(NSTimeInterval *)expiryDuration error:(NSError **)errorOut
{
    // Send the SPC message to the Key Server.
    // Implements communications with the Axinom DRM license server.
    
    NSData *decodedData = nil;
    
    NSString *licenseUrl = @"http://fp-keyos.licensekeyserver.com/getkey";
    NSString *customData = _customData;
    NSMutableURLRequest *ksmRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:licenseUrl]];
    
    NSString *finalString = [NSString stringWithFormat:@"spc=%@&assetId=%@",[requestBytes base64EncodedStringWithOptions:0],assetStr];
    NSData *spcData = [finalString dataUsingEncoding:NSUTF8StringEncoding];
    
    
    // Attaches the license token to license requests:
    [ksmRequest setValue:customData forHTTPHeaderField:@"customData"];
    
    [ksmRequest setHTTPMethod:@"POST"];
    [ksmRequest setHTTPBody:spcData];
    
    NSHTTPURLResponse *ksmResponse = nil;
    NSError *ksmError = nil;
    
    decodedData = [NSURLConnection sendSynchronousRequest:ksmRequest returningResponse:&ksmResponse error:&ksmError];
    return decodedData;
}

- (NSData *)myGetAppCertificateData
{
    NSData *certificate = nil;
    
    // This needs to be implemented to conform to your protocol with the backend/key security module.
    // At a high level, this function gets the application certificate from the server in DER format.
    NSString *certificateUrl = @"http://fp-keyos.licensekeyserver.com/getkey";
    NSURLRequest *certRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:certificateUrl]];
    NSHTTPURLResponse *certResponse = nil;
    NSError *certError = nil;
    
    certificate = [NSURLConnection sendSynchronousRequest:certRequest returningResponse:&certResponse error:&certError];
    
    return certificate;
    
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    AVAssetResourceLoadingDataRequest *dataRequest = loadingRequest.dataRequest;
    NSURL *url = loadingRequest.request.URL;
    NSError *error = nil;
    BOOL handled = NO;
    
    if (![[url scheme] isEqual:URL_SCHEME_NAME])
        return NO;
    
    NSString *assetStr;
    NSData *assetId;
    NSData *requestBytes;
    
    assetStr = [url.absoluteString stringByReplacingOccurrencesOfString:@"skd://" withString:@""];
    assetId = [NSData dataWithBytes: [assetStr cStringUsingEncoding:NSUTF8StringEncoding] length:[assetStr lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    
    // Get the application certificate:
    NSData *certificate = [self myGetAppCertificateData];
    
    /*
     To obtain the Server Playback Context (SPC), we call
     AVAssetResourceLoadingRequest.streamingContentKeyRequestData(forApp:contentIdentifier:options:)
     using the information we obtained earlier.
     */
    requestBytes = [loadingRequest streamingContentKeyRequestDataForApp:certificate
                                                      contentIdentifier:assetId
                                                                options:nil
                                                                  error:&error];
    NSData *responseData = nil;
    NSTimeInterval expiryDuration = 0.0;
    
    // Send the SPC message to the Key Server.
    responseData = [self getContentKeyAndLeaseExpiryfromKeyServerModuleWithRequest:requestBytes
                                                             contentIdentifierHost:assetStr
                                                               leaseExpiryDuration:&expiryDuration
                                                                             error:&error];
    
    // The Key Server returns the CK inside an encrypted Content Key Context (CKC) message in response to
    // the app’s SPC message.  This CKC message, containing the CK, was constructed from the SPC by a
    // Key Security Module in the Key Server’s software.
    if (responseData != nil) {
        
        // Provide the CKC message (containing the CK) to the loading request.
        [dataRequest respondWithData:[[NSData alloc] initWithBase64EncodedData:responseData options:0]];
        
        // Get the CK expiration time from the CKC. This is used to enforce the expiration of the CK.
        if (expiryDuration != 0.0) {
            
            AVAssetResourceLoadingContentInformationRequest *infoRequest = loadingRequest.contentInformationRequest;
            if (infoRequest) {
                infoRequest.renewalDate = [NSDate dateWithTimeIntervalSinceNow:expiryDuration];
                infoRequest.contentType = @"application/octet-stream";
                infoRequest.contentLength = responseData.length;
                infoRequest.byteRangeAccessSupported = NO;
            }
        }
        [loadingRequest finishLoading]; // Treat the processing of the request as complete.
    }
    else {
        [loadingRequest finishLoadingWithError:error];
    }
    
    handled = YES;    // Request has been handled regardless of whether server returned an error.
    
    return handled;
}

- (BOOL)resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForRenewalOfRequestedResource:(AVAssetResourceRenewalRequest *)renewalRequest
{
    return [self resourceLoader:resourceLoader shouldWaitForLoadingOfRequestedResource:renewalRequest];
}

@end



