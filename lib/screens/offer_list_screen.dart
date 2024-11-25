// import 'dart:convert';

import 'package:assumemate/logo/pop_up.dart';
import 'package:assumemate/service/service.dart';
import 'package:assumemate/storage/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:assumemate/components/chat_list.dart';
import 'package:assumemate/components/offer_list.dart';
// import 'package:assumemate/logo/pop_up.dart';
// import 'package:assumemate/service/service.dart';
// import 'package:assumemate/storage/secure_storage.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

class OfferListScreen extends StatefulWidget {
  const OfferListScreen({super.key});

  @override
  State<OfferListScreen> createState() => _OfferListScreenState();
}

class _OfferListScreenState extends State<OfferListScreen> {
  final SecureStorage secureStorage = SecureStorage();
  final ApiService apiService = ApiService();
  List<Map<String, dynamic>> _offers = [];

  Future<void> _getOffers() async {
    try {
      final response = await apiService.getAssumptorListOffer();

      if (response.containsKey('offers')) {
        setState(() {
          _offers = List<Map<String, dynamic>>.from(response['offers']);
        });
      }
    } catch (e) {
      popUp(context, 'Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getOffers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xffFFFCF1),
          leading: IconButton(
            splashColor: Colors.transparent,
            icon: const Icon(
              Icons.arrow_back_ios,
            ),
            color: Colors.black,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text('Offer Lists',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              )),
        ),
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: _offers.isEmpty
              ? const Center(
                  child: Text('No active offers'),
                )
              : RefreshIndicator(
                  onRefresh: _getOffers,
                  color: const Color(0xff4A8AF0),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _offers.length,
                    itemBuilder: (context, index) {
                      final offer = _offers[index];
                      return OfferList(
                        offerId: offer['offer_id'],
                        offerAmnt: offer['offer_price'],
                        listId: offer['list_id'],
                        listImage: offer['list_image'],
                        userId: offer['user_id'],
                        userFullname: offer['user_fullname'],
                        roomId: offer['chatroom_id'],
                      );
                    },
                  ),
                ),
        ));
  }
}
