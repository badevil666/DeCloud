import 'package:flutter/material.dart';

// 🌈 KEEP THIS EXACTLY AS-IS
const kPrimaryGradient = LinearGradient(
  colors: [
    Color(0xFF00C2FF),
    Color.fromRGBO(203, 45, 234, 1),
    Color.fromARGB(255, 234, 45, 45),
  ],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// 🖤 Instagram-style dark surfaces
const kBackgroundColor = Color(0xFF0F1115); // near-black
const kCardColor = Color(0xFF181A20); // dark card surface

// 📝 Typography
const kTextPrimary = Color(0xFFEDEDED); // almost white
const kTextSecondary = Color(0xFF9A9CA5); // muted gray

// 🧱 Borders & dividers (optional but powerful)
const kDividerColor = Color(0xFF24262D);
