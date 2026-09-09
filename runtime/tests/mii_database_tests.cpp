#include "kartpad/mii/mii_database.h"
#include "kartpad/mii/player_identity.h"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <string>
#include <vector>

int main() {
    constexpr std::array<uint8_t, 9> crcVector{
        '1', '2', '3', '4', '5', '6', '7', '8', '9'};
    assert(kartpad::mii::Crc32(crcVector) == 0xCBF43926u);

    constexpr std::array<uint8_t, 6> mac{0x02, 0x17, 0xAB, 0x10, 0x20, 0x30};
    auto database = kartpad::mii::CreateSeedDatabase(mac);
    assert(kartpad::mii::ValidateDatabase(database));

    auto records = kartpad::mii::ListMiis(database);
    assert(records.size() == 1);
    assert(records[0].name == "KartPad");

    auto imported = kartpad::mii::CreateDefaultMii(mac);
    kartpad::mii::WriteMiiName(imported, 0x02, "Racer");
    kartpad::mii::WriteBigEndian32(imported, 0x18, 0x80000002u);
    assert(kartpad::mii::ValidateMii(imported));
    assert(kartpad::mii::ImportMii(database, imported));
    assert(kartpad::mii::ValidateDatabase(database));

    records = kartpad::mii::ListMiis(database);
    assert(records.size() == 2);
    assert(records[1].name == "Racer");
    assert(!kartpad::mii::ImportMii(database, imported));

    constexpr std::array<uint8_t, 12> renamed{
        0, 'K', 0, 'a', 0, 'h', 0, 'r', 0, 'i', 0, 's'};
    const auto createId = kartpad::mii::MiiCreateId(database, records[0].slot);
    assert(kartpad::mii::RenameMii(database, records[0].slot, renamed));
    assert(kartpad::mii::ValidateDatabase(database));
    records = kartpad::mii::ListMiis(database);
    assert(records[0].name == "Kahris");
    constexpr std::array<uint8_t, 2> loneSurrogate{0xD8, 0x3D};
    assert(!kartpad::mii::RenameMii(
        database, records[0].slot, loneSurrogate));

    std::vector<uint8_t> rksys(kartpad::mii::kRksysSize);
    std::copy_n("RKSD0006", 8, rksys.begin());
    std::copy_n("RKPD", 4,
                rksys.begin() + kartpad::mii::kRksysLicenseOffset);
    std::copy(createId.begin(), createId.end(),
              rksys.begin() + kartpad::mii::kRksysLicenseOffset +
                  kartpad::mii::kRksysCreateIdOffset);
    kartpad::mii::UpdateRksysCrc(rksys);
    assert(kartpad::mii::ValidateRksys(rksys));
    std::size_t updatedLicenses = 0;
    assert(kartpad::mii::RenameMatchingLicenses(
        rksys, createId, renamed, updatedLicenses));
    assert(updatedLicenses == 1);
    assert(kartpad::mii::ValidateRksys(rksys));
    const auto storedName = std::span<const uint8_t>(rksys).subspan(
        kartpad::mii::kRksysLicenseOffset + kartpad::mii::kRksysMiiNameOffset,
        renamed.size());
    assert(std::equal(renamed.begin(), renamed.end(), storedName.begin()));

    const std::size_t secondLicense = kartpad::mii::kRksysLicenseOffset +
        kartpad::mii::kRksysLicenseSize;
    std::copy_n("RKPD", 4, rksys.begin() + secondLicense);
    auto secondId = createId;
    secondId[7] ^= 0x5Au;
    std::copy(secondId.begin(), secondId.end(),
              rksys.begin() + secondLicense +
                  kartpad::mii::kRksysCreateIdOffset);
    constexpr std::array<uint8_t, 12> playerName{
        0, 'P', 0, 'l', 0, 'a', 0, 'y', 0, 'e', 0, 'r'};
    std::copy(playerName.begin(), playerName.end(),
              rksys.begin() + secondLicense +
                  kartpad::mii::kRksysMiiNameOffset);
    kartpad::mii::UpdateRksysCrc(rksys);
    const auto licenses = kartpad::mii::ListLicenses(rksys);
    assert(licenses.size() == 2);
    assert(licenses[0].slot == 0);
    assert(licenses[0].name == "Kahris");
    assert(licenses[1].slot == 1);
    assert(licenses[1].name == "Player");
    assert(licenses[1].createId == secondId);

    const auto firstLicenseBeforeRename = std::vector<uint8_t>(
        rksys.begin() + kartpad::mii::kRksysLicenseOffset,
        rksys.begin() + kartpad::mii::kRksysLicenseOffset +
            kartpad::mii::kRksysLicenseSize);
    assert(kartpad::mii::RenameLicense(rksys, 1, secondId, renamed));
    assert(kartpad::mii::ValidateRksys(rksys));
    assert(kartpad::mii::ListLicenses(rksys)[1].name == "Kahris");
    assert(std::equal(firstLicenseBeforeRename.begin(),
                      firstLicenseBeforeRename.end(),
                      rksys.begin() + kartpad::mii::kRksysLicenseOffset));

    const auto beforeRejectedRename = rksys;
    auto wrongSecondId = secondId;
    wrongSecondId[0] ^= 1;
    assert(!kartpad::mii::RenameLicense(
        rksys, 1, wrongSecondId, playerName));
    assert(rksys == beforeRejectedRename);

    assert(kartpad::mii::DeleteLicense(rksys, 1, secondId));
    assert(kartpad::mii::ValidateRksys(rksys));
    assert(kartpad::mii::ListLicenses(rksys).size() == 1);
    assert(std::all_of(rksys.begin() + secondLicense,
                       rksys.begin() + secondLicense +
                           kartpad::mii::kRksysLicenseSize,
                       [](uint8_t byte) { return byte == 0; }));
    assert(!kartpad::mii::DeleteLicense(rksys, 1, secondId));

    auto noMatch = rksys;
    auto unrelatedId = createId;
    unrelatedId[0] ^= 1;
    const std::size_t originalUpdatedLicenses = updatedLicenses;
    assert(kartpad::mii::RenameMatchingLicenses(
        noMatch, unrelatedId, renamed, updatedLicenses));
    assert(updatedLicenses == 0);
    assert(noMatch == rksys);
    updatedLicenses = originalUpdatedLicenses;

    auto damagedRksys = rksys;
    damagedRksys[0x100] ^= 1;
    assert(!kartpad::mii::ValidateRksys(damagedRksys));

    assert(kartpad::mii::RemoveMii(database, records[1].slot));
    records = kartpad::mii::ListMiis(database);
    assert(records.size() == 1);
    assert(!kartpad::mii::RemoveMii(database, records[0].slot));

    auto invalid = imported;
    invalid[0] |= 0x80;
    assert(!kartpad::mii::ValidateMii(invalid));
    assert(!kartpad::mii::ValidateMii(
        std::span<const uint8_t>(invalid.data(), invalid.size() - 1)));
    return 0;
}
