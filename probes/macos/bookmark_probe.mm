#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

#include <algorithm>
#include <cstdio>
#include <cstring>

namespace {

NSString* repositoryRootPath() {
#ifdef SIMPLICITY_ENGINE_SOURCE_DIR
    return [NSString stringWithUTF8String:SIMPLICITY_ENGINE_SOURCE_DIR];
#else
    return [[NSFileManager defaultManager] currentDirectoryPath];
#endif
}

NSURL* tokenFileURL() {
    NSString* dataPath = [repositoryRootPath() stringByAppendingPathComponent:@"data/probe"];
    return [NSURL fileURLWithPath:[dataPath stringByAppendingPathComponent:@"macos-bookmark-token.json"]];
}

void printNSError(NSString* prefix, NSError* error) {
    if (error) {
        std::fprintf(stderr, "%s: %s\n", prefix.UTF8String, error.localizedDescription.UTF8String);
    } else {
        std::fprintf(stderr, "%s\n", prefix.UTF8String);
    }
}

bool ensureTokenDirectory() {
    NSError* error = nil;
    NSURL* tokenURL = tokenFileURL();
    NSURL* dataURL = [tokenURL URLByDeletingLastPathComponent];
    if ([[NSFileManager defaultManager] createDirectoryAtURL:dataURL
                                 withIntermediateDirectories:YES
                                                  attributes:nil
                                                       error:&error]) {
        return true;
    }

        printNSError(@"Failed to create token directory", error);
    return false;
}

NSData* bookmarkDataForFolder(NSURL* folderURL) {
    NSError* error = nil;
    NSURLBookmarkCreationOptions options =
        NSURLBookmarkCreationWithSecurityScope | NSURLBookmarkCreationSecurityScopeAllowOnlyReadAccess;
    NSData* bookmarkData = [folderURL bookmarkDataWithOptions:options
                               includingResourceValuesForKeys:nil
                                                relativeToURL:nil
                                                        error:&error];
    if (!bookmarkData) {
        printNSError(@"Failed to create bookmark data", error);
    }
    return bookmarkData;
}

bool saveToken(NSURL* folderURL, NSData* bookmarkData) {
    if (!ensureTokenDirectory()) {
        return false;
    }

    NSString* token = [bookmarkData base64EncodedStringWithOptions:0];
    NSString* createdAt = [[NSISO8601DateFormatter new] stringFromDate:[NSDate date]];
    NSDictionary* payload = @{
        @"kind": @"macos-security-scoped-bookmark",
        @"version": @1,
        @"folder_url": folderURL.absoluteString,
        @"token": token,
        @"created_at": createdAt
    };

    NSError* error = nil;
    NSData* json = [NSJSONSerialization dataWithJSONObject:payload
                                                   options:(NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys)
                                                     error:&error];
    if (!json) {
        printNSError(@"Failed to serialize token JSON", error);
        return false;
    }

    NSURL* outputURL = tokenFileURL();
    if (![json writeToURL:outputURL options:NSDataWritingAtomic error:&error]) {
        printNSError(@"Failed to write token JSON", error);
        return false;
    }

    std::printf("saved %s\n", outputURL.path.UTF8String);
    std::printf("folder %s\n", folderURL.absoluteString.UTF8String);
    return true;
}

NSDictionary* readTokenPayload() {
    NSError* error = nil;
    NSData* data = [NSData dataWithContentsOfURL:tokenFileURL() options:0 error:&error];
    if (!data) {
        printNSError(@"Failed to read token JSON", error);
        return nil;
    }

    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!object || ![object isKindOfClass:[NSDictionary class]]) {
        printNSError(@"Token JSON is not an object", error);
        return nil;
    }

    return object;
}

NSURL* resolveFolderFromToken(bool* stale) {
    NSDictionary* payload = readTokenPayload();
    if (!payload) {
        return nil;
    }

    NSString* token = payload[@"token"];
    if (![token isKindOfClass:[NSString class]]) {
        std::fprintf(stderr, "Token JSON is missing a string field named \"token\".\n");
        return nil;
    }

    NSData* bookmarkData = [[NSData alloc] initWithBase64EncodedString:token options:0];
    if (!bookmarkData) {
        std::fprintf(stderr, "Token field is not valid base64 bookmark data.\n");
        return nil;
    }

    NSError* error = nil;
    BOOL bookmarkIsStale = NO;
    NSURL* folderURL = [NSURL URLByResolvingBookmarkData:bookmarkData
                                                 options:NSURLBookmarkResolutionWithSecurityScope
                                           relativeToURL:nil
                                     bookmarkDataIsStale:&bookmarkIsStale
                                                   error:&error];
    if (!folderURL) {
        printNSError(@"Failed to resolve bookmark data", error);
        return nil;
    }

    if (stale) {
        *stale = bookmarkIsStale;
    }

    if (bookmarkIsStale) {
        NSData* refreshedBookmarkData = bookmarkDataForFolder(folderURL);
        if (refreshedBookmarkData) {
            std::printf("bookmark was stale; refreshed token JSON\n");
            saveToken(folderURL, refreshedBookmarkData);
        }
    }

    return folderURL;
}

bool isSafeRelativePath(NSString* relativePath) {
    if (relativePath.length == 0 || [relativePath hasPrefix:@"/"]) {
        return false;
    }

    for (NSString* component in [relativePath componentsSeparatedByString:@"/"]) {
        if (component.length == 0 || [component isEqualToString:@"."] ||
            [component isEqualToString:@".."]) {
            return false;
        }
    }

    return true;
}

NSURL* fileURLInsideFolder(NSURL* folderURL, NSString* relativePath) {
    NSURL* fileURL = folderURL;
    for (NSString* component in [relativePath componentsSeparatedByString:@"/"]) {
        fileURL = [fileURL URLByAppendingPathComponent:component isDirectory:NO];
    }
    return fileURL;
}

int chooseFolder() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp activateIgnoringOtherApps:YES];

        NSOpenPanel* panel = [NSOpenPanel openPanel];
        panel.title = @"Choose a folder to bookmark";
        panel.canChooseFiles = NO;
        panel.canChooseDirectories = YES;
        panel.allowsMultipleSelection = NO;
        panel.canCreateDirectories = NO;
        panel.prompt = @"Choose";

        if ([panel runModal] != NSModalResponseOK) {
            std::fprintf(stderr, "No folder selected.\n");
            return 2;
        }

        NSURL* folderURL = panel.URL;
        NSData* bookmarkData = bookmarkDataForFolder(folderURL);
        if (!bookmarkData) {
            return 1;
        }

        return saveToken(folderURL, bookmarkData) ? 0 : 1;
    }
}

int resolveFolder() {
    @autoreleasepool {
        bool stale = false;
        NSURL* folderURL = resolveFolderFromToken(&stale);
        if (!folderURL) {
            return 1;
        }

        std::printf("resolved %s\n", folderURL.absoluteString.UTF8String);
        std::printf("stale %s\n", stale ? "yes" : "no");
        return 0;
    }
}

int loadFile(const char* relativePathArgument) {
    @autoreleasepool {
        NSString* relativePath = [NSString stringWithUTF8String:relativePathArgument];
        if (!isSafeRelativePath(relativePath)) {
            std::fprintf(stderr, "Pass a relative file path inside the bookmarked folder.\n");
            return 2;
        }

        bool stale = false;
        NSURL* folderURL = resolveFolderFromToken(&stale);
        if (!folderURL) {
            return 1;
        }

        BOOL scoped = [folderURL startAccessingSecurityScopedResource];
        NSURL* fileURL = fileURLInsideFolder(folderURL, relativePath);
        NSError* error = nil;
        NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:&error];
        if (!handle) {
            if (scoped) {
                [folderURL stopAccessingSecurityScopedResource];
            }
            printNSError(@"Failed to open file handle", error);
            return 1;
        }

        NSData* data = [handle readDataToEndOfFile];
        [handle closeFile];
        if (scoped) {
            [folderURL stopAccessingSecurityScopedResource];
        }

        std::printf("opened %s\n", fileURL.absoluteString.UTF8String);
        std::printf("bytes %lu\n", static_cast<unsigned long>(data.length));
        std::printf("bookmark_stale %s\n", stale ? "yes" : "no");

        NSUInteger previewLength = std::min<NSUInteger>(data.length, 512);
        NSData* previewData = [data subdataWithRange:NSMakeRange(0, previewLength)];
        NSString* preview = [[NSString alloc] initWithData:previewData encoding:NSUTF8StringEncoding];
        if (preview) {
            std::printf("--- utf8 preview ---\n%s\n", preview.UTF8String);
        } else {
            std::printf("--- hex preview ---\n");
            const unsigned char* bytes = static_cast<const unsigned char*>(previewData.bytes);
            for (NSUInteger index = 0; index < previewLength; ++index) {
                std::printf("%02x%s", bytes[index], ((index + 1) % 16 == 0) ? "\n" : " ");
            }
            if (previewLength % 16 != 0) {
                std::printf("\n");
            }
        }

        return 0;
    }
}

void printUsage(const char* executableName) {
    std::fprintf(stderr,
                 "Usage:\n"
                 "  %s choose\n"
                 "  %s resolve\n"
                 "  %s load <relative-file>\n\n"
                 "The token is stored at data/probe/macos-bookmark-token.json in this repo.\n",
                 executableName,
                 executableName,
                 executableName);
}

} // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 2;
    }

    if (std::strcmp(argv[1], "choose") == 0) {
        return chooseFolder();
    }

    if (std::strcmp(argv[1], "resolve") == 0) {
        return resolveFolder();
    }

    if (std::strcmp(argv[1], "load") == 0) {
        if (argc != 3) {
            printUsage(argv[0]);
            return 2;
        }
        return loadFile(argv[2]);
    }

    printUsage(argv[0]);
    return 2;
}
