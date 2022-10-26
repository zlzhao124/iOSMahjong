A copy of my final project for CSE438, where my group members (see below) and I created an iOS Mahjong app that uses Swift, XCode, and utilizes AR capabilities with packages like ARKit and UIKit as well as multiplayer connection.

# Project Name: Mahjong AR

## Group Member: Will Ma, Xuyan Qin, Yiwen Ju, Zhuying(Helen) Jiang, Zach Zhao

## Game Setup
To start the game, we need four (4) devices with AR capabilities. Given that the delivery of graphics depends on device hardware resources, we suggest to use devices with A12 Bionic or higher, and we advice to use devices with LiDAR hardware, namely the iPad Pro that's currently on sale at Apple Store, iPhone 12 Pro, and iPhone 12 Pro Max. We would also need a flat surface.

### Device Requirement:
minimum device requirement: iPhone 8 Plus
minimum system requirement: iOS 14.0

Optimal device: iPhone 12 Pro Max
Optimal system: iOS 14.2

## Starting the game
First, you have to open the device wifi and bluetooth. Then have the four devices nearby to each other, choose on one device "Start as a host," and choose "Join my friends" on other devices. For the host, tap on your friends' names to send invites. Accept the invitations on other devices. When all devices are connected and ready, the 'Done' button on top right of the host will become available. Click the button to launch the AR game.

## Playing the game
Once all players arrive into the AR view, gently tap on each device's screen to set up the AR objects. While doing this, be sure to aim at a nice, flat surface, so that the objects will be stable in the plane. Avoid moving your device violently as well--that's beyond ARKit's capability to handle. It might take few seconds for the server (host) to prepare the game and distribute cards; so if the first touch doesn't work it might be the server's still working hard. Wait a few seconds and try again.

## Game turns
All the players will take turns to play a card in a counter clock order. Special moves like Kong, Chow, Pong will disrupt this order and direct the turn to the player whoever can make such moves, and the game proceed as usual in a counter clock-wise order. 

### Play a card
To choose and play a card, drag it upwards on your screen. You'll see it on the table once it's out. If you are not sure whether it's your turn or not, just play a card. It will be on the table if it is truly your turn. 


### Kong
Kong happens when you have three identical cards, other player plays the fourth card out on the table or you managed to grab it from the deck. (the deck is invisible in our game) When you place a "Kong" move (by pressing the Kong button displaying on the screen now), you have these four cards in your current card deck, displayed at the end to other players. Furthermore, it's now your turn to begin, drawing a card and play. 

### Pong
Kong happens when you have two identical cards, other player plays a third card out on the table or you managed to grab it from the deck. (the deck is invisible in our game) When you place a "Pong" move (by pressing the Pong button displaying on the screen now), you have these three cards in your current card deck, displayed at the end to other players. Furthermore, it's now your turn to begin, you don't get to draw another card now, but you can get rid of a card from your deck.

### Chow
Chow happens right before the game enters in your turn. You can see that the card last player placed in front of you can form a flush of three with two other cards from your card deck. In order to place a move of "Chow", you have to press the Chow button displaying on the screen now, and play the two corresponding "Chow" cards from your deck with the gesture in "Play". If you accidently played the wrong card in a wrong correspondence, don't worry. The wrong cards will insert back to your deck when you complete two draws, and now you are ready to play now. When you place a "Chow" move, you have these three cards in your current card deck, displayed at the end to other players. Furthermore, it's now your turn to begin, you don't get to draw another card now, but you can get rid of a card from your deck.

### Pass
Pass goes along with any of the three special moves above. If you think it is in your disadvantage to make a special move, pressing a pass button will help you skip this decision. However, you don't have a turn to play.


### Win or Lose
Once you satisfy the condition of winning the game, a button will pop up. After you click the "win" button, there will be an alert message showing you win the game and other players will have an alert message showing they lose the game. All the players will be asked to replay game and will be directed back to the initial login page. You can then follow the previous instruction to search for players and play the game.
