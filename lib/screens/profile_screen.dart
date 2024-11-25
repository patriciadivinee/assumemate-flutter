import 'dart:convert';

import 'package:assumemate/components/listing_item.dart';
import 'package:assumemate/logo/pop_up.dart';
import 'package:assumemate/provider/follow_provider.dart';
import 'package:assumemate/screens/ListingRequestScreen.dart';
import 'package:assumemate/screens/assumptor_listing_screen.dart';
import 'package:assumemate/screens/following_screen.dart';
import 'package:assumemate/screens/offer_list_screen.dart';
import 'package:assumemate/screens/transaction.dart';
import 'package:assumemate/screens/user_auth/edit_application_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:assumemate/components/offer_list.dart';
import 'package:assumemate/logo/loading_animation.dart';
import 'package:assumemate/provider/profile_provider.dart';
import 'package:assumemate/screens/account_settings_screen.dart';
import 'package:assumemate/screens/edit_profile_screen.dart';
// import 'package:assumemate/screens/offer_list_screen.dart';
import 'package:assumemate/screens/payment_screen.dart';
import 'package:assumemate/service/service.dart';
import 'package:assumemate/storage/secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? errorMsg;
  double _coins = 0;
  // List<Map<String, dynamic>> _offers = [];
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _followers = [];
  late Future<List<dynamic>> _activeListings;
  String? token;
  String? _applicationStatus;

  final SecureStorage secureStorage = SecureStorage();
  final ApiService apiService = ApiService();
  String? _userType;

  Future<void> _fetchCoins() async {
    final wallId = await secureStorage.getUserId();
    try {
      double totalCoins = await apiService.getTotalCoins(int.parse(wallId!));
      setState(() {
        _coins = totalCoins;
      });
    } catch (e) {
      print('Error fetching coins: $e');
    }
  }

  Future<void> _addCoins(int coinsToAdd) async {
    final wallId = await secureStorage.getUserId();
    try {
      await apiService.addCoinsToWallet(int.parse(wallId!), coinsToAdd);
      await _fetchCoins();
    } catch (e) {
      popUp(context, 'Error adding coins: $e');
    }
  }

  Future<List<dynamic>> fetchUserListings(String status) async {
    final token = await secureStorage.getToken();

    final String? baseURL = dotenv.env['API_URL'];

    final response = await http.get(
      Uri.parse('$baseURL/assumptor/all/$status/listings/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      print(data);
      return data['listings'];
    } else {
      // Return an empty list and show a message instead of throwing an error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load $status listings'),
          duration: const Duration(seconds: 3),
        ),
      );
      return []; // Return an empty list in case of failure
    }
  }

  Future<List<dynamic>> fetchRatings() async {
    try {
      final token = await secureStorage.getToken();
      final String? baseURL = dotenv.env['API_URL'];

      if (token == null || baseURL == null) {
        throw Exception('Token or API URL not found');
      }

      final response = await http.get(
        Uri.parse('$baseURL/view/rate'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}'); // Log the response body

      if (response.statusCode == 200) {
        List<dynamic> ratings = json.decode(response.body);

        // Check if the response is an empty list
        if (ratings.isEmpty) {
          print('No ratings available');
          return [];
        }

        print('Ratings Data: $ratings'); // Log the decoded data

        return ratings.map((rating) {
          return {
            'name': rating['from_user_id'] != null
                ? rating['from_user_id']['user_prof_fname'] +
                    ' ' +
                    rating['from_user_id']['user_prof_lname']
                : 'Anonymous', // Ensure this field is available
            'rating': rating['rating_value'] ?? 0,
            'comment': rating['review_comment'] ?? 'No comment provided',
          };
        }).toList();
      } else {
        throw Exception('Failed to load ratings');
      }
    } catch (error) {
      print('Error: $error');
      throw Exception('Error fetching ratings: $error');
    }
  }

  Widget buildListingGrid(Future<List<dynamic>> futureListings) {
    return FutureBuilder<List<dynamic>>(
      future: futureListings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Failed to load listings: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No listings available'));
        } else {
          return GridView.builder(
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              mainAxisExtent: MediaQuery.of(context).size.width * .50,
            ),
            physics: const BouncingScrollPhysics(),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var listing = snapshot.data![index];
              var content = listing['list_content'];

              String title = 'No title';

              if (content['category'] == 'Real Estate') {
                // title = content['title'];
                title = 'No title';
              } else {
                title =
                    '${content['make']} ${content['model']} (${content['year']}) - ${content['transmission']}';
              }

              return ListingItem(
                title: title,
                imageUrl: content['images'],
                description: content['description'] ?? 'No Description',
                listingId: listing['list_id'].toString(),
                assumptorId: listing['user_id'].toString(),
                price: content['price'].toString(),
              );
            },
          );
        }
      },
    );
  }

  Widget buildRatingList(Future<List<dynamic>> futureRatings) {
    return FutureBuilder<List<dynamic>>(
      future: futureRatings,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(
              child: Text('Failed to load ratings: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No ratings available'));
        } else {
          return ListView.builder(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              var rating = snapshot.data![index];
              var name = rating['name'] ?? 'Anonymous';
              var stars = (rating['rating'] ?? 0)
                  .toInt(); // Convert rating to integer for stars
              var comment = rating['comment'] ?? 'No comment provided';

              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '★' * stars, // Display stars based on rating value
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      comment,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Divider(), // Add a divider for spacing
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }

  void _getToken() async {
    final tok = await secureStorage.getToken();
    final status = await secureStorage.getApplicationStatus();
    final type = await secureStorage.getUserType();
    setState(() {
      token = tok;
      _applicationStatus = status;
      _userType = type;
    });
  }

  void _getFollower() async {
    try {
      final response = await apiService.getFollowers();

      if (response.containsKey('follower')) {
        setState(() {
          _followers = List<Map<String, dynamic>>.from(response['follower']);
        });
        print(_followers);
      }
    } catch (e) {
      popUp(context, 'An error occureed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getToken();
    _getFollower();
    _fetchCoins();
    _activeListings = fetchUserListings('ACTIVE');
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);
    final followProvider = Provider.of<FollowProvider>(context);
    final tabTextStyle =
        GoogleFonts.poppins(textStyle: const TextStyle(fontSize: 13));

    if (profileProvider.isLoading) {
      return const LoadingAnimation();
    } else if (profileProvider.errorMessage.isNotEmpty) {
      Text(
        profileProvider.errorMessage,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      );
    }
    if (profileProvider.userProfile.isNotEmpty) {
      return Scaffold(
          body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return [
              SliverAppBar(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ));
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.solidPenToSquare,
                        size: 25,
                        color: Color(0xffFFFFFF),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const AccontSettingsScreen()),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      color: const Color(0xffFFFCF1),
                      iconSize: 30,
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF4A8AF0),
                forceElevated: true,
                pinned: true,
                floating: true,
                expandedHeight: 250,
                collapsedHeight: 60,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 15),
                  background: Stack(children: [
                    // Positioned.fill(
                    //   child: Image.network(
                    //     'https://pbs.twimg.com/media/GQ6Tse_aQAABFI2?format=jpg&name=large',
                    //     fit: BoxFit
                    //         .cover, // Ensure the image covers the entire area
                    //   ),
                    // ),
                    Positioned.fill(
                        child: Image.asset(
                      'assets/images/cover-photo1.jpeg',
                      fit: BoxFit.fill,
                    )),
                    Positioned(
                      bottom: 15,
                      left: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundImage: NetworkImage(
                                profileProvider.userProfile['user_prof_pic']),
                            radius: 40,
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${profileProvider.userProfile['user_prof_fname']} ${profileProvider.userProfile['user_prof_lname']}',
                                      style: const TextStyle(
                                        color: Color(0xffFFFFFF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    _applicationStatus == 'APPROVED'
                                        ? const Icon(
                                            Icons.verified_rounded,
                                            color: Color(0xffFFFFFF),
                                            size: 18,
                                          )
                                        : _applicationStatus == 'REJECTED'
                                            ? Tooltip(
                                                message: 'Update your profile',
                                                textStyle: TextStyle(
                                                    color: Colors.black),
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0)),
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    final updatedStatus =
                                                        await Navigator.of(
                                                                context)
                                                            .push(
                                                                MaterialPageRoute(
                                                      builder: (context) =>
                                                          EditApplicationScreen(),
                                                    ));
                                                    if (updatedStatus != null) {
                                                      setState(() {
                                                        // Update the UI based on the updated status
                                                        _applicationStatus =
                                                            updatedStatus;
                                                      });
                                                    }
                                                  },
                                                  child: const Icon(
                                                    Icons.info_outline_rounded,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (context) => FollowScreen(
                                            title: 'Followers',
                                            follow: _followers,
                                          ),
                                        ));
                                      },
                                      child: Text(
                                        _followers.length < 2
                                            ? '${_followers.length} Follower'
                                            : '${_followers.length} Followers',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xffFFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 30, // Adjust the height as needed
                                      child: VerticalDivider(
                                        thickness: 1.5,
                                        color: Color(0xffFFFFFF),
                                        width: 20,
                                        indent: 4,
                                        endIndent: 4,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    FollowScreen(
                                                      title: 'Following',
                                                      follow: followProvider
                                                          .followingIds,
                                                    )));
                                      },
                                      child: Text(
                                        '${followProvider.followingCount} Following',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xffFFFFFF),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ]),
                  collapseMode: CollapseMode.pin,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Wallet',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(
                            top: 10, bottom: 10, right: 8, left: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 2,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  FontAwesomeIcons.coins,
                                  color: Color(0xffF2D120),
                                  size: 32,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _coins.toString(),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text(
                                      'Coins',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () {
                                if (_applicationStatus == 'APPROVED') {
                                  popUp(context,
                                      'You need to be verified to top-up');
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentScreen(
                                        addCoins: _addCoins,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.add),
                              iconSize: 28,
                              color: const Color(0xFF4A8AF0),
                            ),
                          ],
                        ),
                      ),
                      if (_userType == 'assumptor')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'Manage',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildCard(
                              'Listings',
                              Icons.content_paste,
                              const Color(0xff34a36e),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AssumptorListingScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCard(
                              'Listing Applications',
                              Icons.pending_actions_rounded,
                              const Color(0xFFFF5722),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ListingRequestScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCard(
                              'Offers',
                              Icons.attach_money,
                              const Color(0xffD42020),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const OfferListScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildCard(
                              'Transaction History',
                              Icons.receipt_long_outlined,
                              const Color(0xff626362),
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const TransactionHistoryScreen(),
                                ),
                              ),
                            ),
                          ],
                        )
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: MySliverPersistentHeaderDelegate(
                  TabBar(
                    labelColor: Colors.black,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: UnderlineTabIndicator(
                      borderSide: const BorderSide(
                        width: 4,
                        color: Color(0xff4A8AF0),
                      ),
                      insets: const EdgeInsets.symmetric(
                        horizontal: (30 - 4) / 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tabs: [
                      Tab(child: Text('Listings', style: tabTextStyle)),
                      Tab(child: Text('Ratings', style: tabTextStyle)),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: Container(
            padding: const EdgeInsets.all(10),
            child: TabBarView(
              children: [
                buildListingGrid(_activeListings),
                buildRatingList(fetchRatings()),
              ],
            ),
          ),
        ),
      ));
    } else {
      return const Center(child: Text('No profile data available.'));
    }
  }

  Widget _buildCard(
      String title, IconData icon, Color color, VoidCallback? callback) {
    return GestureDetector(
      onTap: callback,
      child: Container(
        padding: const EdgeInsets.only(top: 10, bottom: 10, right: 8, left: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 13))
              ],
            ),
            IconButton(
              onPressed: callback,
              icon: const Icon(Icons.chevron_right_rounded),
              iconSize: 28,
              color: const Color(0xFF4A8AF0),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class MySliverPersistentHeaderDelegate extends SliverPersistentHeaderDelegate {
  MySliverPersistentHeaderDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xffFFFCF1),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(MySliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
