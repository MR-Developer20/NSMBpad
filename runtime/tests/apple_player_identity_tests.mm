#import "KartPadMiiManager.h"
#include "kartpad/mii/player_identity.h"
#include <cassert>
#include <cstdlib>
#include <filesystem>
#include <vector>

static void Write(NSString *path, const std::vector<uint8_t>& bytes) {
  assert([NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:nil]);
  assert([[NSData dataWithBytes:bytes.data() length:bytes.size()]
      writeToFile:path options:NSDataWritingAtomic error:nil]);
}

int main() {
  @autoreleasepool {
    char temporary[] = "/tmp/kartpad-identity-tests.XXXXXX";
    const char *directory = mkdtemp(temporary);
    assert(directory != nullptr);
    setenv("KARTPAD_MII_TEST_SUPPORT_ROOT", directory, 1);
    NSString *root = [NSString stringWithUTF8String:directory];
    auto database = kartpad::mii::CreateSeedDatabase({0x02, 0x17, 0xab, 0x10, 0x20, 0x30});
    const auto identity = kartpad::mii::MiiCreateId(database, 0);
    Write([root stringByAppendingPathComponent:@"NAND/shared2/menu/FaceLib/RFL_DB.dat"], database);
    std::vector<uint8_t> save(kartpad::mii::kRksysSize, 0);
    std::copy_n("RKSD0006", 8, save.begin());
    const auto offset = kartpad::mii::kRksysLicenseOffset;
    std::copy_n("RKPD", 4, save.begin() + offset);
    std::copy(identity.begin(), identity.end(), save.begin() + offset + kartpad::mii::kRksysCreateIdOffset);
    kartpad::mii::WriteMiiName(save, offset + kartpad::mii::kRksysMiiNameOffset, "Player");
    // Stand-ins for account/progress bytes must survive every rename.
    save[offset + 0x90] = 0x72;
    save[offset + 0x4a0] = 0x35;
    kartpad::mii::UpdateRksysCrc(save);
    NSString *original = [root stringByAppendingPathComponent:@"NAND/title/00010004/524d4350/data/rksys.dat"];
    NSString *retro = [root stringByAppendingPathComponent:@"RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat"];
    Write(original, save);
    Write(retro, save);
    NSData *before = [NSData dataWithContentsOfFile:original];
    NSData *createId = [NSData dataWithBytes:identity.data() length:identity.size()];
    NSError *error = nil;
    assert(KartPadStageLicenseRename(@"original", 0, createId, @"Racer", &error));
    auto records = KartPadLicenseRecords(&error);
    assert(records.count == 2 && [records[0][@"name"] isEqual:@"Racer"]);
    assert([records[0][@"pendingOperation"] isEqual:@"rename"]);
    assert([before isEqual:[NSData dataWithContentsOfFile:original]]);
    assert(!KartPadStagePlayerName(0, @"Other", nullptr, &error));
    error = nil;
    assert(KartPadApplyPendingMiiDatabase(&error));
    assert(!KartPadHasPendingMiiChanges());
    NSData *after = [NSData dataWithContentsOfFile:original];
    const auto* bytes = static_cast<const uint8_t*>(after.bytes);
    for (size_t index = 0; index < save.size(); ++index) {
      const bool nameByte = index >= offset + kartpad::mii::kRksysMiiNameOffset &&
          index < offset + kartpad::mii::kRksysMiiNameOffset + kartpad::mii::kMiiNameByteSize;
      const bool crcByte = index >= kartpad::mii::kRksysCoreCrcOffset && index < kartpad::mii::kRksysCoreCrcOffset + 4;
      if (!nameByte && !crcByte) assert(bytes[index] == save[index]);
    }
    NSUInteger linked = 0;
    assert(KartPadStagePlayerName(0, @"Both", &linked, &error) && linked == 2);
    records = KartPadLicenseRecords(&error);
    assert([records[0][@"name"] isEqual:@"Both"] && [records[1][@"name"] isEqual:@"Both"]);
    assert(KartPadApplyPendingMiiDatabase(&error));
    assert(!KartPadStageMiiRemoval(0, &error));
    error = nil;
    assert(KartPadStageLicenseDeletion(@"original", 0, createId, &error));
    records = KartPadLicenseRecords(&error);
    assert([records[0][@"pendingOperation"] isEqual:@"delete"]);
    NSData *retroBefore = [NSData dataWithContentsOfFile:retro];
    assert(KartPadApplyPendingMiiDatabase(&error));
    assert(KartPadLicenseRecords(&error).count == 1);
    assert([retroBefore isEqual:[NSData dataWithContentsOfFile:retro]]);
    assert([[NSFileManager.defaultManager contentsOfDirectoryAtPath:
        [root stringByAppendingPathComponent:@"SaveBackups"] error:nil] count] >= 4);
    // Only this test-created, exact temporary tree is removed.
    std::filesystem::remove_all(directory);
    puts("Apple identity staging, pending preview, backup and preservation tests passed.");
  }
}
