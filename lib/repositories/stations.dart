import '../shared/models/models.dart';

/// The stops on the demo route. Shared by the mock and real repositories;
/// `code` is the station code vendors register under in the backend
/// (vendors.station_code), and is what the merchant app saves.
const List<Station> kStations = [
  Station(id: 1,  name: 'Udupi Junction',     code: 'UD',   eta: '14:18', minsAway: 8,   platform: 1, vendorCount: 3),
  Station(id: 2,  name: 'Padubidri',          code: 'PDD',  eta: '13:52', minsAway: 22,  platform: 1, vendorCount: 1),
  Station(id: 3,  name: 'Barkur',             code: 'BKJ',  eta: '14:36', minsAway: 28,  platform: 1, vendorCount: 1),
  Station(id: 4,  name: 'Mulki',              code: 'MULK', eta: '13:38', minsAway: 38,  platform: 1, vendorCount: 1),
  Station(id: 5,  name: 'Surathkal',          code: 'SL',   eta: '13:28', minsAway: 48,  platform: 1, vendorCount: 1),
  Station(id: 7,  name: 'Kundapura',          code: 'KUDA', eta: '15:02', minsAway: 58,  platform: 1, vendorCount: 1),
  Station(id: 6,  name: 'Mangalore Jn',       code: 'MAJN', eta: '13:05', minsAway: 72,  platform: 2, vendorCount: 2),
  Station(id: 12, name: 'Mangalore Central',  code: 'MAQ',  eta: '12:50', minsAway: 85,  platform: 1, vendorCount: 1),
  Station(id: 8,  name: 'Byndoor',            code: 'BYNR', eta: '15:48', minsAway: 98,  platform: 1, vendorCount: 1),
  Station(id: 10, name: 'Bhatkal',            code: 'BTJL', eta: '16:18', minsAway: 128, platform: 1, vendorCount: 1),
  Station(id: 11, name: 'Murdeshwar',         code: 'MRDW', eta: '16:42', minsAway: 148, platform: 1, vendorCount: 1),
  Station(id: 9,  name: 'Gokarna Road',       code: 'GOK',  eta: '17:22', minsAway: 186, platform: 1, vendorCount: 2),
];

