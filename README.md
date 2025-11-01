# كلمات متقاطعة - Real-Time Multiplayer Crosswords

<p align="center">
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/icon/icon.png?raw=true" width="180" alt="Crosswords Logo"/><br>
  <b>Real-time collaborative Arabic crosswords puzzle game</b>
</p>

---

## 📱 About
A Flutter-based multiplayer crosswords app with real-time collaboration. Multiple players can solve the same puzzle together. Fully optimized for Arabic language with complete RTL support.

---

## 📸 Screenshots

<p align="center">
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/screens/Screenshot_2025-11-01-01-20-41-706_com.nunya.crosswords-edit.png?raw=true" width="30%"/>
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/screens/Screenshot_2025-11-01-01-17-43-460_com.nunya.crosswords-edit.png?raw=true" width="30%"/>
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/screens/Screenshot_2025-11-01-01-22-14-039_com.nunya.crosswords-edit.png?raw=true" width="30%"/><br><br>
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/screens/Screenshot_2025-11-01-01-23-11-228_com.nunya.crosswords-edit.png?raw=true" width="30%"/>
  <img src="https://github.com/KareemNashef/Crosswords/blob/main/assets/screens/Screenshot_2025-11-01-01-23-38-860_com.nunya.crosswords-edit.png?raw=true" width="30%"/>
</p>

---

## ✨ Features

### Real-Time Multiplayer
- **Simultaneous Gameplay**: Multiple players solve the same puzzle at the same time  
- **Live User Presence**: See which friends are currently playing  
- **Instant Synchronization**: Cell updates appear in real-time  
- **Conflict Resolution**: Handles concurrent edits reliably  

### Competitive Elements
- **Color-Coded Contributions**: Each player’s correct answers in unique color  
- **Score Tracking**: Points awarded for solving clues  
- **Real-time Leaderboard**: Track leaders during gameplay  
- **Individual Statistics**: Monitor personal performance  

### Arabic Language Support
- **Full RTL Implementation**: Proper right-to-left layout  
- **Arabic Keyboard Optimization**: Seamless input  
- **100+ Puzzles**: Curated Arabic crosswords  
- **Cultural Content**: Clues and answers relevant to Arabic speakers  

### Technical Features
- **Firebase Real-time Database**: Instant sync across devices  
- **Offline Puzzle Viewing**: Browse completed puzzles without internet  
- **Responsive Design**: Adapts to multiple screen sizes  

---

## 🛠️ Technical Stack
- **Framework**: Flutter (Dart)  
- **Backend**: Firebase Realtime Database  
- **Authentication**: Firebase Auth (optional multiplayer)  
- **Language**: Arabic (RTL layout)  
- **State Management**: Provider  
- **UI Framework**: Material Design with RTL support  

---

## 🏗️ Key Technical Challenges
1. **RTL Layout Implementation**  
   - Overcame Flutter RTL rendering complexities  
   - Custom widget positioning for Arabic text flow  
   - Handled bidirectional content  

2. **Real-Time Synchronization**  
   - Firebase Realtime Database
   - puzzles/{puzzleId}/
   - cells/ # Grid state
   - players/ # Active users
   - scores/ # Current scores

3. **Concurrent Edit Handling**  
- Optimistic Updates for instant UI response  
- Conflict Detection for simultaneous edits  
- Last-Write-Wins resolution  
- Visual feedback for active cells  

4. **Player Presence System**  
- Real-time tracking of connected players  
- Automatic cleanup of disconnected users  
- Color indicators for active participants  

---

## 📊 Technical Achievements
- Sub-100ms latency for real-time responsiveness  
- Scalable room system supporting multiple sessions  
- Efficient data structure to minimize Firebase reads and writes  
- Correct handling of complex RTL text scenarios  

---

## 🎮 How It Works
- **Create/Join Game**: Start or join a session  
- **Solve Together**: Fill answers while seeing others progress  
- **Compete & Collaborate**: Race for points and help with clues  
- **Track Progress**: View leaderboard and personal statistics  

---

## 📝 Development Notes
- Explored real-time multiplayer architecture  
- Implemented robust RTL UI in Flutter  
- Learned concurrent data handling and conflict resolution  

---

## 📧 Contact
**Kareem Nashef**  
📩 Kareem.na@outlook.com  
🔗 [LinkedIn](https://linkedin.com/in/kareem-nashef)  
💻 [GitHub](https://github.com/KareemNashef)  

---

<p align="center">
Built with Flutter 💙 | بُني باستخدام فلاتر  
</p>

<p align="center">
Personal project exploring real-time multiplayer systems and RTL development
</p>
