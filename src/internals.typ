#let functions = plugin("plugin.wasm")

#let replay-game(starting-position, turns) = {
  let game = functions.replay_game(
    bytes(starting-position.fen),
    turns.map(bytes).join(bytes((0, )))
  )
  array(game).split(0).map(position => (
    type: "board-n-pieces:fen",
    fen: str(bytes(position))
  ))
}

#let game-from-pgn(pgn) = {
  let game = functions.game_from_pgn(
    bytes(pgn),
  )
  array(game).split(0).map(position => (
    type: "board-n-pieces:fen",
    fen: str(bytes(position))
  ))
}

/// Converts a `board-n-pieces:fen-position` to a `board-n-pieces:position`.
/// For positions, this is the identity function.
#let resolve-position(position) = {
  let message = "expected a position (hint: you can construct a position with the `position` function)"

  assert.eq(type(position), dictionary, message: message)

  if position.type == "board-n-pieces:position" {
    return position
  }

  if position.type == "board-n-pieces:fen" {
    // A `fen` object contains a `fen` entry, which is a full fen string.
    let parts = position.fen.split(" ")
    return (
      type: "board-n-pieces:position",
      fen: position.fen,
      board: parts.at(0)
        .split("/")
        .rev()
        .map(fen-rank => {
          ()
          for s in fen-rank {
            if "0".to-unicode() <= s.to-unicode() and s.to-unicode() <= "9".to-unicode() {
              (none, ) * int(s)
            } else {
              (s, )
            }
          }
        }),
      active: parts.at(1),
      castling-availabilities: (
        white-king-side: "K" in parts.at(2),
        white-queen-side: "Q" in parts.at(2),
        black-king-side: "k" in parts.at(2),
        black-queen-side: "q" in parts.at(2),
      ),
      en-passant-target-square: if parts.at(3) != "-" { parts.at(3) },
      halfmove: int(parts.at(4)),
      fullmove: int(parts.at(5)),
    )
  }

  panic(message)
}

/// Mirror fen
#let mirror-fen(fen_string) = {
  // Split the FEN string into its components
  let parts = fen_string.split(" ")
  let position = parts.at(0)
  let active_color = parts.at(1)
  let castling = parts.at(2)
  let en_passant = parts.at(3)
  let halfmove = parts.at(4)
  let fullmove = parts.at(5)
  
  // Helper function to swap case
  let swap_case(c) = {
    // Mapping for pieces
    let case_map = (
      // Lowercase to uppercase
      "p": "P", "r": "R", "n": "N", "b": "B", "q": "Q", "k": "K",
      // Uppercase to lowercase
      "P": "p", "R": "r", "N": "n", "B": "b", "Q": "q", "K": "k"
    )
    
    // Return the swapped case character
    if c in case_map {
      return case_map.at(c)
    }
    
    // If not a chess piece, return as is
    return c
  }
  
  // 1. Mirror the position (ranks are reversed, files are reversed, pieces are flipped)
  let ranks = position.split("/")
  let mirrored_ranks = ()
  
  // For each rank
  for rank in ranks {
    let mirrored_rank = ""
    
    // Process each character in the rank
    for char in rank.codepoints() {
      // Check if char is a digit between 1-8
      if "12345678".contains(char) {
        // Numbers (empty squares) stay the same
        mirrored_rank += char
      } else {
        // Swap the case of pieces (white becomes black and vice versa)
        mirrored_rank += swap_case(char)
      }
    }
    
    // Create a reversed version of mirrored_rank
    let reversed_rank = ""
    for i in range(mirrored_rank.len(), 0, step: -1) {
      reversed_rank += mirrored_rank.slice(i - 1, i)
    }
    
    mirrored_ranks.push(reversed_rank)
  }
  
  // Reverse the order of ranks to mirror vertically
  let reversed_ranks = ()
  for i in range(mirrored_ranks.len(), 0, step: -1) {
    reversed_ranks.push(mirrored_ranks.at(i - 1))
  }
  
  // Join the ranks back with "/"
  let mirrored_position = reversed_ranks.join("/")
  
  // 2. Flip the active color
  let mirrored_active_color = if active_color == "w" { "b" } else { "w" }
  
  // 3. Mirror the castling rights
  let mirrored_castling = "-"
  if castling != "-" {
    mirrored_castling = ""
    // In a completely mirrored position, castling rights are flipped both ways
    if castling.contains("K") { mirrored_castling += "q" }
    if castling.contains("Q") { mirrored_castling += "k" }
    if castling.contains("k") { mirrored_castling += "Q" }
    if castling.contains("q") { mirrored_castling += "K" }
    
    if mirrored_castling == "" { mirrored_castling = "-" }
  }
  
  // 4. Mirror the en passant square
  let mirrored_en_passant = "-"
  if en_passant != "-" {
    // For en passant, we need to flip both file and rank
    let file = en_passant.at(0)
    let rank = en_passant.at(1)
    
    // Map the files (a->h, b->g, etc.)
    let file_map = (
      "a": "h", "b": "g", "c": "f", "d": "e",
      "e": "d", "f": "c", "g": "b", "h": "a"
    )
    
    // Map the ranks (1->8, 2->7, etc.)
    let rank_map = (
      "1": "8", "2": "7", "3": "6", "4": "5",
      "5": "4", "6": "3", "7": "2", "8": "1"
    )
    
    mirrored_en_passant = file_map.at(file) + rank_map.at(rank)
  }
  
  // Combine all parts back into a FEN string
  // return mirrored_position + " " + mirrored_active_color + " " + mirrored_castling + " " + mirrored_en_passant + " " + halfmove + " " + fullmove
  // We only take the position
  return mirrored_position 
}

/// Returns the index of a file.
#let file-index(f) = f.to-unicode() - "a".to-unicode()

/// Returns the index of a rank.
#let rank-index(r) = int(r) - 1

/// Returns the coordinates of a square given a square name.
#let square-coordinates(s) = {
  let (f, r) = s.clusters()
  (file-index(f), rank-index(r))
}

/// Returns the name of a square given its coordinates.
#let square-name(s) = {
  let (f, r) = s
  str.from-unicode(f + "a".to-unicode()) + str(r + 1)
}

#let stroke-sides(arg) = {
  let sides = rect(stroke: arg).stroke

  if type(sides) != dictionary {
    sides = (
      left: sides,
      top: sides,
      right: sides,
      bottom: sides,
    )
  }

  (
    left: none,
    top: none,
    right: none,
    bottom: none,
    ..sides,
  )
}
