import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../shared/models/models.dart';
import '../repositories/discovery_repository.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'vendor_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiscoveryRepository _repo = LocoBiteApp.repo;

  late List<Station> _stations;
  int _selectedStation = 0;
  bool _vegOnly = false;
  String _search = '';
  final List<CartItem> _cart = [];
  late TrainInfo _train;
  bool _editingTrain = false;
  int _navIndex = 0;

  late TextEditingController _trainNumCtrl;
  late TextEditingController _coachCtrl;
  late TextEditingController _seatCtrl;
  late TextEditingController _arrivalCtrl;

  @override
  void initState() {
    super.initState();
    _stations = _repo.getUpcomingStations();
    _train = _repo.getCurrentTrain();
    _trainNumCtrl = TextEditingController(text: _train.number);
    _coachCtrl    = TextEditingController(text: _train.coach);
    _seatCtrl     = TextEditingController(text: _train.seat);
    _arrivalCtrl  = TextEditingController(text: _train.arrival);
  }

  @override
  void dispose() {
    _trainNumCtrl.dispose(); _coachCtrl.dispose();
    _seatCtrl.dispose(); _arrivalCtrl.dispose();
    super.dispose();
  }

  List<Vendor> get _filteredVendors {
    final stationId = _stations[_selectedStation].id;
    return _repo.getVendorsForStation(stationId).where((v) {
      if (_vegOnly && !v.cuisineTags.contains('Veg')) return false;
      if (_search.isNotEmpty &&
          !v.name.toLowerCase().contains(_search.toLowerCase()) &&
          !v.cuisineTags.join(' ').toLowerCase().contains(_search.toLowerCase())) return false;
      return true;
    }).toList();
  }

  int get _cartCount => _cart.fold(0, (s, i) => s + i.qty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Good afternoon',
                      style: GoogleFonts.nunito(
                        fontSize: 11, color: Colors.white54,
                        fontWeight: FontWeight.w700, letterSpacing: 1,
                      )),
                    Text(ApiService.currentCustomer?.name ?? 'Arjun Kumar',
                      style: GoogleFonts.nunito(
                        fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  ]),
                  const Spacer(),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_none_rounded,
                          color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white12,
                          shape: const CircleBorder(),
                        ),
                      ),
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.amber, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTrainBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: _editingTrain ? _buildTrainEditForm() : _buildTrainDisplay(),
    );
  }

  Widget _buildTrainDisplay() {
    return Row(
      children: [
        const Icon(Icons.train_rounded, size: 16, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_train.number} Duronto Exp',
              style: GoogleFonts.nunito(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            Text('Coach ${_train.coach} · Seat ${_train.seat}',
              style: GoogleFonts.nunito(color: Colors.white60, fontSize: 11)),
          ]),
        ),
        if (_train.delayed)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.amber.withOpacity(0.4)),
            ),
            child: Text('+${_train.delayMins}m delay',
              style: GoogleFonts.nunito(
                color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        IconButton(
          onPressed: () => setState(() => _editingTrain = true),
          icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white12,
            minimumSize: const Size(28, 28),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainEditForm() {
    return Column(
      children: [
        Row(
          children: [
            _trainField('TRAIN', _trainNumCtrl),
            const SizedBox(width: 8),
            _trainField('COACH', _coachCtrl),
            const SizedBox(width: 8),
            _trainField('SEAT', _seatCtrl),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _trainField('ARRIVAL', _arrivalCtrl),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _train.delayed = !_train.delayed),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _train.delayed ? AppColors.amber : Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Delayed?',
                  style: GoogleFonts.nunito(
                    color: _train.delayed ? const Color(0xFF7C5200) : Colors.white70,
                    fontWeight: FontWeight.w800, fontSize: 11,
                  )),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => setState(() {
                _train.number  = _trainNumCtrl.text;
                _train.coach   = _coachCtrl.text;
                _train.seat    = _seatCtrl.text;
                _train.arrival = _arrivalCtrl.text;
                _editingTrain  = false;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              child: Text('Save', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _trainField(String label, TextEditingController ctrl) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.nunito(
            fontSize: 8, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: 1)),
          const SizedBox(height: 2),
          TextField(
            controller: ctrl,
            style: GoogleFonts.nunito(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white12,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStationScroll(),
          _buildSearchBar(),
          _buildFilterChips(),
          _buildVendorList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStationScroll() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('UPCOMING STATIONS',
                style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w800,
                  color: AppColors.muted, letterSpacing: 1.5)),
              const Spacer(),
              Text('${_stations.length} stops',
                style: GoogleFonts.nunito(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 16),
            itemCount: _stations.length,
            itemBuilder: (_, i) => _StationCard(
              station: _stations[i],
              isSelected: _selectedStation == i,
              onTap: () => setState(() => _selectedStation = i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: GoogleFonts.nunito(
            fontSize: 13, color: AppColors.foreground, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Search vendors in ${_stations[_selectedStation].name}...',
            hintStyle: GoogleFonts.nunito(color: AppColors.muted.withOpacity(0.5), fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted, size: 20),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ['All', 'Veg', 'Open Now', 'Trusted'].map((f) {
          final active = f == 'Veg' && _vegOnly;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () { if (f == 'Veg') setState(() => _vegOnly = !_vegOnly); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppColors.primary : AppColors.primaryLight, width: 1.5),
                ),
                child: Text(f,
                  style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.muted,
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVendorList() {
    final list = _filteredVendors;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_stations[_selectedStation].name} · ${list.length} vendors',
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w800,
              color: AppColors.muted, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          if (list.isEmpty)
            _buildEmptyState()
          else
            ...list.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _VendorCard(
                vendor: v,
                onTap: () {
                  if (ApiService.currentCustomer != null) {
                    ApiService.recordVendorTap(
                      ApiService.mapVendorId(v.id),
                      ApiService.currentCustomer!.id,
                    );
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => VendorScreen(
                      vendor: v,
                      cart: _cart,
                      onCartChanged: (c) => setState(() {}),
                    )),
                  );
                },
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const Text('🍽', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('No vendors found',
              style: GoogleFonts.nunito(
                fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.foreground)),
            const SizedBox(height: 4),
            Text('Try a different station or clear filters.',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.shopping_bag_outlined, 'Cart'),
      (Icons.receipt_long_outlined, 'Orders'),
      (Icons.person_outline_rounded, 'Account'),
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.primaryLight))),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) {
            final active = _navIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _navIndex = i);
                  if (i == 1) Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CartScreen(cart: _cart, train: _train,
                      onCartChanged: (c) => setState(() {})),
                  ));
                  if (i == 3) Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const ProfileScreen()));
                },
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(items[i].$1,
                            size: 22,
                            color: active ? AppColors.primary : Colors.grey.shade400),
                          if (i == 1 && _cartCount > 0)
                            Positioned(
                              right: -6, top: -6,
                              child: Container(
                                width: 16, height: 16,
                                decoration: const BoxDecoration(
                                  color: AppColors.amber, shape: BoxShape.circle),
                                child: Center(child: Text('$_cartCount',
                                  style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w900,
                                    color: Colors.white))),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(items[i].$2,
                        style: GoogleFonts.nunito(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: active ? AppColors.primary : Colors.grey.shade400,
                        )),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final Station station;
  final bool isSelected;
  final VoidCallback onTap;
  const _StationCard({required this.station, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.primaryLight, width: 2),
          boxShadow: isSelected ? [BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(station.code,
                  style: GoogleFonts.nunito(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white60 : AppColors.muted)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : (station.minsAway < 20 ? AppColors.amber.withOpacity(0.15) : AppColors.primaryLight),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    station.minsAway < 60
                      ? '${station.minsAway}m'
                      : '${station.minsAway ~/ 60}h${station.minsAway % 60}m',
                    style: GoogleFonts.nunito(
                      fontSize: 9, fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : AppColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(station.name,
              style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : AppColors.foreground)),
            Text('${station.vendorCount} vendors · Plt ${station.platform}',
              style: GoogleFonts.nunito(
                fontSize: 10,
                color: isSelected ? Colors.white60 : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor vendor;
  final VoidCallback onTap;
  const _VendorCard({required this.vendor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryLight),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    vendor.imageUrl,
                    height: 130, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 130, color: AppColors.primaryLight,
                      child: const Center(child: Icon(Icons.restaurant_rounded,
                        color: AppColors.primary, size: 40)),
                    ),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: vendor.isOpen ? AppColors.green : Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(vendor.isOpen ? 'OPEN' : 'CLOSED',
                      style: GoogleFonts.nunito(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ),
                Positioned(
                  bottom: 8, left: 10,
                  child: Wrap(spacing: 6, children: [
                    if (vendor.trusted)
                      _BadgePill(label: '✓ Trusted', bgColor: AppColors.primary),
                    if (vendor.zeroCommission)
                      _BadgePill(label: 'Zero Commission', bgColor: Colors.white.withOpacity(0.2),
                        textColor: Colors.white),
                  ]),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(vendor.name,
                            style: GoogleFonts.nunito(
                              fontSize: 14, fontWeight: FontWeight.w900,
                              color: AppColors.foreground)),
                          const SizedBox(height: 2),
                          Text(vendor.cuisineTags.join(' · '),
                            style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: AppColors.green),
                              const SizedBox(width: 2),
                              Text('${vendor.rating}',
                                style: GoogleFonts.nunito(
                                  fontSize: 11, fontWeight: FontWeight.w900,
                                  color: AppColors.green)),
                            ],
                          ),
                        ),
                        if (vendor.fssai)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('FSSAI ✓',
                                style: GoogleFonts.nunito(
                                  fontSize: 9, fontWeight: FontWeight.w800,
                                  color: AppColors.muted)),
                            ),
                          ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(vendor.priceRange,
                        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
                      Text('${vendor.reviewCount.toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} reviews',
                        style: GoogleFonts.nunito(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _BadgePill({required this.label, required this.bgColor,
    this.textColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
        style: GoogleFonts.nunito(
          fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
    );
  }
}
