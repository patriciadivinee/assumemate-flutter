import 'dart:convert';

import 'package:assumemate/components/transaction_list.dart';
import 'package:assumemate/logo/pop_up.dart';
import 'package:assumemate/screens/offer_list_screen.dart';
import 'package:http/http.dart' as http;
import 'package:assumemate/service/service.dart';
import 'package:assumemate/storage/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AssumeManagementScreen extends StatefulWidget {
  const AssumeManagementScreen({super.key});

  @override
  State<AssumeManagementScreen> createState() => _AssumeManagementScreenState();
}

class _AssumeManagementScreenState extends State<AssumeManagementScreen> {
  final SecureStorage secureStorage = SecureStorage();
  final ApiService apiService = ApiService();
  bool _isLoading = false;

  late Future<List<dynamic>> _onGoingTransactions;
  late Future<List<dynamic>> _completedTransaction;

  Future<List<dynamic>> fetchCurrentTransactions() async {
    final userType = await SecureStorage().getUserType();
    final token = await secureStorage.getToken();
    final apiUrl = userType == 'assumptor'
        ? Uri.parse('$baseURL/assumptor/on-going/transactions/')
        : Uri.parse('$baseURL/assumee/on-going/transactions/');
    final response = await http.get(
      apiUrl,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data);
      return data['invoices'];
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Future<List<dynamic>> fetchCompletedTransactions() async {
    final userType = await SecureStorage().getUserType();
    final token = await secureStorage.getToken();
    final apiUrl = userType == 'assumptor'
        ? Uri.parse('$baseURL/assumptor/completed/transactions/')
        : Uri.parse('$baseURL/assumee/completed/transactions/');
    final response = await http.get(
      apiUrl,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print(data);
      return data['invoices'];
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Widget transList(Future<List<dynamic>> transaction) {
    return FutureBuilder(
        future: transaction,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Failed to load transactions'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transaction available'));
          } else {
            return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final trans = snapshot.data![index];
                  return TransactionList(
                    transaction: trans,
                  );
                });
          }
        });
  }

  @override
  void initState() {
    _onGoingTransactions = fetchCurrentTransactions();
    _completedTransaction = fetchCompletedTransactions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final tabTextStyle =
        GoogleFonts.poppins(textStyle: const TextStyle(fontSize: 13));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xffFFFCF1),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            splashColor: Colors.transparent,
            icon: const Icon(
              Icons.arrow_back_ios,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: const Text(
            "Assume Management",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
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
              Tab(
                  child: Text(
                'In Progress',
                style: tabTextStyle,
              )),
              Tab(
                  child: Text(
                'Completed',
                style: tabTextStyle,
              )),
            ],
          ),
        ),
        body: Container(
          padding: const EdgeInsets.all(2),
          child: TabBarView(
            children: [
              transList(_onGoingTransactions),
              transList(_completedTransaction),
            ],
          ),
        ),
      ),
    );
  }
}