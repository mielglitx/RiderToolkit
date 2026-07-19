// lib/main.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// GLOBALS: RIDER PROFILE MEMORY
// ==========================================
class AppProfile {
  static String telegramId = "";
  static String riderName = "";
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences prefs = await SharedPreferences.getInstance();
  AppProfile.telegramId = prefs.getString('telegramId') ?? "";
  AppProfile.riderName = prefs.getString('riderName') ?? "";
  runApp(const LokalexRiderApp());
}

class LokalexRiderApp extends StatelessWidget {
  const LokalexRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lokalex Toolkit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blueAccent,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
      ),
      home: AppProfile.telegramId.isEmpty ? const LoginScreen() : const SmartCartScreen(),
    );
  }
}

// ==========================================
// SCREEN 0: SECURE RIDER LOGIN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _isLoggingIn = false;

  Future<void> _loginDevice() async {
    if (_idController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Paki-lagay ang iyong Telegram ID.")));
      return;
    }

    setState(() => _isLoggingIn = true);

    try {
      final response = await http.post(
        Uri.parse("https://lokalexdeliver.com/api/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"telegram_id": _idController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        String fetchedName = data['rider_name'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('riderName', fetchedName);
        await prefs.setString('telegramId', _idController.text.trim());

        AppProfile.riderName = fetchedName;
        AppProfile.telegramId = _idController.text.trim();

        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SmartCartScreen()),
        );
      } else {
        _showError(data['error'] ?? "Failed to login. Please check your ID.");
      }
    } catch (e) {
      _showError("Hindi makakonekta sa server. Please check your internet connection.");
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Login Failed", style: TextStyle(color: Colors.redAccent)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🛵 Lokalex Rider Login"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Welcome to Lokalex!", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 10),
            const Text("Paki-lagay ang iyong authorized Telegram User ID upang makapag-login sa system.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            TextField(
              controller: _idController,
              keyboardType: TextInputType.number,
              enabled: !_isLoggingIn,
              decoration: const InputDecoration(labelText: "Telegram User ID", prefixIcon: Icon(Icons.numbers), border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            _isLoggingIn 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _loginDevice,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, fixedSize: const Size.fromHeight(50)),
                  child: const Text("Secure Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// DATA MODELS
// ==========================================
class CartItem {
  String id = UniqueKey().toString(); 
  String item;
  double price;
  String? category;

  CartItem({required this.item, required this.price, this.category});

  Map<String, dynamic> toJson() => {'item': item, 'price': price, 'category': category};
}

// ==========================================
// SCREEN 1: SMART CART & ITEM MANAGEMENT
// ==========================================
class SmartCartScreen extends StatefulWidget {
  const SmartCartScreen({super.key});

  @override
  State<SmartCartScreen> createState() => _SmartCartScreenState();
}

class _SmartCartScreenState extends State<SmartCartScreen> {
  final List<CartItem> _notepad = [];
  final Set<String> _selectedItems = {}; 
  
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();

  void _addItem() {
    if (_itemNameController.text.trim().isEmpty) return;
    double price = double.tryParse(_itemPriceController.text) ?? 0.0;
    
    setState(() {
      _notepad.add(CartItem(item: _itemNameController.text.trim(), price: price, category: null));
    });
    
    _itemNameController.clear();
    _itemPriceController.clear();
    Navigator.pop(context);
  }

  // Interactive Slide-to-Delete confirmation layout sheet
  Future<bool> _showSlideToDeleteSheet(String titleMessage) async {
    double sliderValue = 0.0;
    bool confirmDelete = false;

    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: const Color(0xFF1E1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_sweep, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      titleMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text("I-drag pakanan ang slider para kumpirmahin ang pagbura.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 30),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Text(
                              ">>>> SLIDE TO DELETE >>>>",
                              style: TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                          ),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.redAccent.withValues(alpha: 0.5),
                              inactiveTrackColor: Colors.transparent,
                              thumbColor: Colors.redAccent,
                              overlayColor: Colors.red.withValues(alpha: 0.2),
                              trackHeight: 50,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
                            ),
                            child: Slider(
                              value: sliderValue,
                              onChanged: (value) {
                                setSheetState(() {
                                  sliderValue = value;
                                });
                              },
                              onChangeEnd: (value) {
                                if (value >= 0.9) {
                                  confirmDelete = true;
                                  Navigator.pop(context);
                                } else {
                                  setSheetState(() {
                                    sliderValue = 0.0; // Bounce back if not fully slid to the right
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return confirmDelete;
  }

  void _handleDeleteSelected() async {
    bool proceed = await _showSlideToDeleteSheet("Burahin ang ${_selectedItems.length} na napiling item(s)?");
    if (proceed) {
      setState(() {
        _notepad.removeWhere((item) => _selectedItems.contains(item.id));
        _selectedItems.clear();
      });
    }
  }

  void _handleClearAll() async {
    bool proceed = await _showSlideToDeleteSheet("Sigurado ka bang gusto mong i-clear ang buong cart?");
    if (proceed) {
      setState(() {
        _notepad.clear();
        _selectedItems.clear();
      });
    }
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("➕ Magdagdag ng Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _itemNameController, decoration: const InputDecoration(labelText: "Pangalan ng Item o Pabili"), textCapitalization: TextCapitalization.sentences),
            TextField(controller: _itemPriceController, decoration: const InputDecoration(labelText: "Presyo (Iwanang 0 kung task)"), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: _addItem, child: const Text("Add")),
        ],
      ),
    );
  }

  void _editPrice(int index) {
    TextEditingController priceEditController = TextEditingController(text: _notepad[index].price == 0.0 ? "" : _notepad[index].price.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Magkano ang ${_notepad[index].item}?"),
        content: TextField(controller: priceEditController, decoration: const InputDecoration(labelText: "I-type ang presyo"), keyboardType: const TextInputType.numberWithOptions(decimal: true), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() { _notepad[index].price = double.tryParse(priceEditController.text) ?? 0.0; });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _validateAndProceedOffline() {
    if (_notepad.isEmpty) {
      _showErrorAlert("Wala pang laman ang cart mo.");
      return;
    }
    if (_notepad.any((i) => i.price == 0.0) || _notepad.any((i) => i.category == null && i.price > 0.0)) {
      _showErrorAlert("⚠️ ACTION BLOCKED:\nKailangang ayusin ang presyo o kategorya ng lahat ng item bago magpatuloy.");
      return;
    }

    double marketTotal = _notepad.where((i) => i.category == 'Market').fold(0, (s, i) => s + i.price);
    double storeTotal = _notepad.where((i) => i.category == 'Store').fold(0, (s, i) => s + i.price);
    
    double autoMarket = marketTotal > 0 ? (marketTotal / 500.0).ceil() * 15.0 : 0.0;
    double autoHandling = storeTotal > 0 ? (storeTotal / 500.0).ceil() * 10.0 : 0.0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeeWizardScreen(
          notepad: _notepad,
          subtotal: marketTotal + storeTotal,
          autoHandling: autoHandling,
          autoMarket: autoMarket,
        ),
      ),
    );
  }

  void _showErrorAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Aksyon Hinarang", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  void _showProfileInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Device Registered", style: TextStyle(color: Colors.blueAccent)),
        content: Text("This app is securely locked and registered under the name: ${AppProfile.riderName}."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = _notepad.fold(0, (sum, item) => sum + item.price);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🛒 Lokalex Smart Cart"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(icon: const Icon(Icons.manage_accounts, color: Colors.grey), onPressed: _showProfileInfo),
        actions: [
          if (_selectedItems.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _handleDeleteSelected, tooltip: "Delete Selected")
          else if (_notepad.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.redAccent), onPressed: _handleClearAll, tooltip: "Clear All")
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: const Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Rider: ${AppProfile.riderName}", style: const TextStyle(fontSize: 14, color: Colors.blueAccent)),
                Text("₱${subtotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ],
            ),
          ),
          Expanded(
            child: _notepad.isEmpty
                ? const Center(child: Text("Walang laman ang cart. Magdagdag gamit ang + button.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    itemCount: _notepad.length,
                    itemBuilder: (context, index) {
                      final item = _notepad[index];
                      bool isTask = item.price == 0.0;

                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.horizontal,
                        confirmDismiss: (direction) async {
                          return await _showSlideToDeleteSheet("Tanggalin si \"${item.item}\" sa cart list?");
                        },
                        onDismissed: (direction) {
                          setState(() {
                            _selectedItems.remove(item.id);
                            _notepad.removeAt(index);
                          });
                        },
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        secondaryBackground: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          color: isTask ? const Color(0xFF2D1F10) : const Color(0xFF1E1E1E),
                          child: ListTile(
                            leading: Checkbox(
                              value: _selectedItems.contains(item.id),
                              onChanged: (bool? selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedItems.add(item.id);
                                  } else {
                                    _selectedItems.remove(item.id);
                                  }
                                });
                              },
                            ),
                            title: Text("${index + 1}. ${item.item}", style: TextStyle(fontWeight: FontWeight.w500, color: isTask ? Colors.orangeAccent : Colors.white)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text("Market"),
                                    selected: item.category == "Market",
                                    onSelected: isTask ? null : (selected) => setState(() => item.category = selected ? "Market" : null),
                                  ),
                                  const SizedBox(width: 6),
                                  ChoiceChip(
                                    label: const Text("Store"),
                                    selected: item.category == "Store",
                                    onSelected: isTask ? null : (selected) => setState(() => item.category = selected ? "Store" : null),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(isTask ? "Kulang Presyo" : "₱${item.price.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: isTask ? Colors.orangeAccent : Colors.white)),
                                const SizedBox(height: 4),
                                GestureDetector(onTap: () => _editPrice(index), child: const Text("✏️ Edit", style: TextStyle(color: Colors.blueAccent, fontSize: 13)))
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _showAddItemDialog,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, fixedSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text("Add Item", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _validateAndProceedOffline,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, fixedSize: const Size.fromHeight(50)),
                      child: const Text("🧾 Create Receipt", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 2: INTERACTIVE FEE CONFIGURATOR WIZARD
// ==========================================
class FeeWizardScreen extends StatefulWidget {
  final List<CartItem> notepad;
  final double subtotal;
  final double autoHandling;
  final double autoMarket;

  const FeeWizardScreen({
    super.key,
    required this.notepad,
    required this.subtotal,
    required this.autoHandling,
    required this.autoMarket,
  });

  @override
  State<FeeWizardScreen> createState() => _FeeWizardScreenState();
}

class _FeeWizardScreenState extends State<FeeWizardScreen> {
  late double handlingFee;
  late double marketFee;
  int storeCount = 1;
  double multiStopFee = 0.0;
  double deliveryFee = 0.0;
  double discount = 0.0;
  
  bool isEPayment = false;
  double ePaymentFee = 0.0;
  bool isFreeDeliveryBypass = false; 

  @override
  void initState() {
    super.initState();
    handlingFee = widget.autoHandling;
    marketFee = widget.autoMarket;
  }

  void _updateMultiStop() {
    setState(() {
      multiStopFee = storeCount > 1 ? (storeCount - 1) * 10.0 : 0.0;
    });
  }

  double _calculateEPaymentFee(double baseAmount) {
    if (baseAmount <= 0) return 0;
    if (baseAmount <= 1000) return 15;
    return 15 + ((baseAmount - 1000) / 500).ceil() * 5;
  }

  double get grandTotal {
    double effectiveHandling = isFreeDeliveryBypass ? 0.0 : handlingFee;
    double effectiveMarket = isFreeDeliveryBypass ? 0.0 : marketFee;
    double effectiveMulti = isFreeDeliveryBypass ? 0.0 : multiStopFee;
    double effectiveDelivery = isFreeDeliveryBypass ? 0.0 : deliveryFee;

    double total = widget.subtotal + effectiveHandling + effectiveMarket + effectiveMulti + effectiveDelivery - discount;
    if (isEPayment) {
      ePaymentFee = _calculateEPaymentFee(total);
      total += ePaymentFee;
    } else {
      ePaymentFee = 0.0;
    }
    return total;
  }

  void _openManualEdit(String label, double currentVal, Function(double) onSave) {
    if (isFreeDeliveryBypass) return; 
    TextEditingController controller = TextEditingController(text: currentVal.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("I-override ang $label"),
        content: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(suffixText: "₱"), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() { onSave(double.tryParse(controller.text) ?? 0.0); });
              Navigator.pop(context);
            },
            child: const Text("Apply"),
          )
        ],
      ),
    );
  }

  void _attemptGeneration() {
    if (deliveryFee == 0.0 && !isFreeDeliveryBypass) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("⚠️ Kulang sa Detalye", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
          content: const Text("Paki-input ang Rider Delivery Fee muna.\n\nKung ang order na ito ay walang charge, paki-check ang \"Libreng Deliberi / No Delivery Fee\" option sa ibaba."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Sige po"))
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinalReceiptScreen(
          notepad: widget.notepad,
          subtotal: widget.subtotal,
          handling: isFreeDeliveryBypass ? 0.0 : handlingFee,
          market: isFreeDeliveryBypass ? 0.0 : marketFee,
          multistore: isFreeDeliveryBypass ? 0.0 : multiStopFee,
          delivery: isFreeDeliveryBypass ? 0.0 : deliveryFee,
          discount: discount,
          epayment: ePaymentFee,
          grandTotal: grandTotal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🧾 Patakbuhin ang Fee Wizard")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildFeeTile("Handling Fee (Store Items)", isFreeDeliveryBypass ? 0.0 : handlingFee, (val) => handlingFee = val, isAuto: true),
          _buildFeeTile("Market Fee", isFreeDeliveryBypass ? 0.0 : marketFee, (val) => marketFee = val, isAuto: true),
          
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text("Ilang Physical Stores ang dinaanan?", style: TextStyle(fontSize: 14, color: Colors.white70))),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                        onPressed: (storeCount > 1 && !isFreeDeliveryBypass) ? () {
                          storeCount--;
                          _updateMultiStop();
                        } : null,
                      ),
                      Text(isFreeDeliveryBypass ? "0" : storeCount.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.greenAccent),
                        onPressed: !isFreeDeliveryBypass ? () {
                          storeCount++;
                          _updateMultiStop();
                        } : null,
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          _buildFeeTile("Multi-Stop Additional Fee", isFreeDeliveryBypass ? 0.0 : multiStopFee, (val) => multiStopFee = val, isAuto: true),
          
          _buildFeeTile("Rider Delivery Fee Matrix", isFreeDeliveryBypass ? 0.0 : deliveryFee, (val) => deliveryFee = val),
          _buildFeeTile("Discount Bawas", discount, (val) => discount = val, isDiscount: true),
          
          const Divider(height: 20),

          Card(
            color: const Color(0xFF1B1212),
            child: CheckboxListTile(
              title: const Text("🎁 Libreng Deliberi / No Delivery Fee", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.orangeAccent)),
              subtitle: const Text("I-check ito kung walang sasaguting fees/charges ang customer."),
              value: isFreeDeliveryBypass,
              activeColor: Colors.orange,
              secondary: const Icon(Icons.card_giftcard, color: Colors.orangeAccent),
              onChanged: (bool? value) => setState(() => isFreeDeliveryBypass = value ?? false),
            ),
          ),
          
          Card(
            color: const Color(0xFF1A1A1A),
            child: SwitchListTile(
              title: const Text("📱 Customer ePayment Via G-Cash/Maya"),
              subtitle: Text(isEPayment ? "Auto Adjusted Fee: ₱${ePaymentFee.toStringAsFixed(2)}" : "Magbabayad ng Cash (Walang Extra Charges)"),
              value: isEPayment,
              secondary: Icon(isEPayment ? Icons.phonelink_ring : Icons.payments, color: Colors.blueAccent),
              onChanged: (bool value) => setState(() => isEPayment = value),
            ),
          ),
          
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: const Color(0xFF1E291B), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("🔥 DYNAMIC GRAND TOTAL:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text("₱${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, fixedSize: const Size.fromHeight(50)),
            onPressed: _attemptGeneration,
            child: const Text("Generate Official Receipt", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildFeeTile(String title, double value, Function(double) onSave, {bool isAuto = false, bool isDiscount = false}) {
    bool isDisabled = isFreeDeliveryBypass && title != "Discount Bawas";
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isDisabled ? Colors.black : null,
      child: ListTile(
        title: Text(title, style: TextStyle(fontSize: 14, color: isDisabled ? Colors.grey : Colors.white70)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuto && value > 0 && !isDisabled)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text("AUTO", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            Text(
              "${isDiscount ? '-' : ''}₱${value.toStringAsFixed(2)}",
              style: TextStyle(fontWeight: FontWeight.bold, color: isDisabled ? Colors.grey : isDiscount ? Colors.redAccent : Colors.white),
            ),
            Icon(Icons.chevron_right, size: 16, color: isDisabled ? Colors.transparent : Colors.grey),
          ],
        ),
        onTap: isDisabled ? null : () => _openManualEdit(title, value, onSave),
      ),
    );
  }
}

// ==========================================
// SCREEN 3: FINAL OFFICIAL RECEIPT OVERVIEW
// ==========================================
class FinalReceiptScreen extends StatefulWidget {
  final List<CartItem> notepad;
  final double subtotal;
  final double handling;
  final double market;
  final double multistore;
  final double delivery;
  final double discount;
  final double epayment;
  final double grandTotal;

  const FinalReceiptScreen({
    super.key,
    required this.notepad,
    required this.subtotal,
    required this.handling,
    required this.market,
    required this.multistore,
    required this.delivery,
    required this.discount,
    required this.epayment,
    required this.grandTotal,
  });

  @override
  State<FinalReceiptScreen> createState() => _FinalReceiptScreenState();
}

class _FinalReceiptScreenState extends State<FinalReceiptScreen> {
  late String riderIdCode;
  late String fullReceiptText;
  bool isLogging = true;

  @override
  void initState() {
    super.initState();
    _generateReceiptData();
    _silentBackgroundLog();
  }

  void _generateReceiptData() {
    String dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    String rawCode = "${AppProfile.telegramId}_$dateStr";
    
    var bytes = utf8.encode(rawCode);
    var digest = md5.convert(bytes);
    riderIdCode = "RID-${digest.toString().substring(0, 5).toUpperCase()}";

    String itemsSection = widget.notepad.map((i) => "🔸 ${i.item} - ₱${i.price.toStringAsFixed(2)}").join("\n");
    
    String feesSection = "";
    if (widget.handling > 0) feesSection += "🔹 Handling Fee: ₱${widget.handling.toStringAsFixed(2)}\n";
    if (widget.market > 0) feesSection += "🔹 Market Fee: ₱${widget.market.toStringAsFixed(2)}\n";
    if (widget.multistore > 0) feesSection += "🔹 Multistore Fee: ₱${widget.multistore.toStringAsFixed(2)}\n";
    if (widget.delivery > 0) feesSection += "🔹 Delivery Fee: ₱${widget.delivery.toStringAsFixed(2)}\n";
    if (widget.epayment > 0) feesSection += "🔹 ePayment Processing Fee: ₱${widget.epayment.toStringAsFixed(2)}\n";
    if (widget.discount > 0) feesSection += "🔻 Discount: -₱${widget.discount.toStringAsFixed(2)}\n";
    if (feesSection.isEmpty) feesSection = "🔹 Wala pong karagdagang fees.\n";

    String timeStr = DateFormat('MMMM dd, yyyy | hh:mm a').format(DateTime.now());

    fullReceiptText = "🧾 **LOKALEX OFFICIAL RECEIPT** 🧾\n\n"
        "📅 **Date:** $timeStr\n"
        "🛵 **Rider:** ${AppProfile.riderName}\n"
        "🔑 **Rider ID Code:** `$riderIdCode`\n"
        "➖➖➖➖➖➖➖➖➖➖➖➖\n"
        "🛍️ **ITEMS:**\n$itemsSection\n\n"
        "💵 **Subtotal:** ₱${widget.subtotal.toStringAsFixed(2)}\n"
        "➖➖➖➖➖➖➖➖➖➖➖➖\n"
        "📋 **FEES:**\n$feesSection"
        "➖➖➖➖➖➖➖➖➖➖➖➖\n"
        "🔥 **GRAND TOTAL: ₱${widget.grandTotal.toStringAsFixed(2)}** 🔥\n\n"
        "💙 Salamat sa pagtitiwala sa Lokalex!";
  }

  Future<void> _silentBackgroundLog() async {
    final payload = {
      "user_id": AppProfile.telegramId,
      "rider_name": AppProfile.riderName,
      "txn_code": riderIdCode,
      "notepad": widget.notepad.map((i) => i.toJson()).toList(),
      "fees": {
        "Handling": widget.handling,
        "Market": widget.market,
        "Multistore": widget.multistore,
        "Delivery": widget.delivery,
        "Discount": widget.discount,
        "ePayment": widget.epayment,
      },
      "grand_total": widget.grandTotal,
    };

    try {
      await http.post(
        Uri.parse("https://lokalexdeliver.com/api/receipt/log"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
    } catch (e) {
      // Background catch dropouts safely
    } finally {
      if (mounted) setState(() => isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 Resibo Preview"),
        actions: [
          if (isLogging) const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.greenAccent)))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
                child: SingleChildScrollView(
                  child: Text(
                    fullReceiptText,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, fixedSize: const Size.fromHeight(50)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fullReceiptText));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Resibo copied to clipboard!")));
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text("Copy Receipt", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, fixedSize: const Size.fromHeight(50)),
                    onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.done_all, color: Colors.white),
                    label: const Text("Done & Clear", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}