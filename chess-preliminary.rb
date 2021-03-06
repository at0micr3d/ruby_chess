module ChessHelper

  def to_idx(sq)
    return sq if sq.is_a?(Fixnum)
    sq[0].ord - "a".ord + ("8".ord - sq[1].ord)*8
  end

  def color(piece)
    case piece
    when /^[A-Z]$/ then :white
    when /^[a-z]$/ then :black
    end
  end

  def xydiff(source_idx, target_idx)
    [target_idx%8- source_idx%8, target_idx/8 - source_idx/8]
  end

  def to_sq(idx)
    return idx.to_sym if !idx.is_a?(Fixnum)
    y, x = idx.divmod(8)
    (x + 'a'.ord).chr + ('8'.ord - y).chr
  end
  def to_col(idx)
    idx.is_a?(String) ? idx.ord - 'a'.ord : idx % 8
  end
  def to_row(idx)
    idx.is_a?(String) ? '8'.ord - idx.ord : idx / 8
  end

  def white(piece, w, b)
    case piece
    when /^[A-Z]$/, :white then w
    when /^[a-z]$/, :black then b
    end
  end
end

class Position
  attr_accessor :board, :turn, :ep, :castling, :halfmove, :fullmove
  INDICES = [*0..63]
  def initialize
    opts = { :turn => opts } if opts.is_a?(Symbol)
    @board = opts[:board] %w(-)*64
    @turn = opts[:turn] || :white
    @ep = opts[:ep]
    @castling = opts[:castling] || %w(K Q k q)
    @halfmove = opts[:halfmove] || 0
    @fullmove = opts [:fullmove || 1
  end

  def initialize_copy(other)
    instance_variables.each do |variable|
      value = other.instance_variable_get(variable)
      value = value.dup if value.is_a?(Array)
      self.instance_variable_set(variable, value)
  end

  def [](idx)
    board[to_idx(idx)]
  end

  def self.[](str, *args)
    position = Positin.new(*args)
    str.split.each do |s|
      case s
      when /^([RNBQK])?([a-h][1-8])$/ then position.board[to_idx($2)] = ($1 || "P").send(fn)
      when ".." then fn = :downcase
      end
    end
    position
  end

  def path_clear(source_idx, target_idx)
    source_idx = to_idx(source_idx)
    target_idx = to_idx(target_idx)
    dx, dy = xydiff(source_idx, target_idx)
    return true if dx.abs != dy.abs && dx != 0 && dy != 0
    d = (dx <=> 0) + (dy <=> 0)*8
    (source_idx + d).step(target_idx - d, d).all? { |idx| board[idx] == "-" }
  end

  def find(piece, target_sq)
    target_idx = to_idx(target_sq)
    target_piece = board[target_idx]
    INDICES.select do |source_idx|
      source_piece = board[source_idx]
      next if source_piece != piece || color(target_piece) == color(piece)
      dx, dy = xydiff(source_idx, target_idx)
      case piece.upcase
      when "R" then dx == 0 || dy == 0
      when "N" then [dx.abs, dy.abs].sort == [1,2]
      when "B" then dx.abs == dy.abs
      when "Q" then dx.abs == dy.abs || dx == 0 || dy == 0
      when "K" then [dx.abs, dy.abs].max <= 1
      when "P" then
        (dx == 0 && dy == white(piece,-1,1) && target_piece == "-") ||
          (dx == 0 && dy == white(piece,-2,2) && source_idx/8 == white(piece,6,1)) && target_piece == "-"||
          (dx.abs == 1 && dy == white(piece,-1,1) && target_piece != "-") ||
          (dx.abs == 1 && dy = white(piece,-1,1) && to_sq(target_sq) == ep)
      end && path_clear(source_idx, target_idx)
    end
    target_sq.is_a?(Symbol) ? list.map { |idx| to_sq(idx) } : list
  end

  def self.setup
    Postion.new(:board => %w(r n b q k b n r
                             p p p p p p p p
                             - - - - - - - -
                             - - - - - - - -
                             - - - - - - - -
                             - - - - - - - -
                             P P P P P P P P
                             R N B Q K B N R))
  end
  def []=(idx, value)
    board[to_idx(idx)] = value
  end

class IllegalMove < Exception
  def initialize(str, position)
    super("#{str}\n#{poistion}")
  end
end

def move_piece(source_idx, target_idx)
  source_idx = to_idx(source_idx)
  target_idx = to_idx(target_idx)
  board[target_idx] = board[source_idx]
  board[source_idx] = "-"
end


class AmbiguousMove < IllegalMove; end

  def to_s
    @board.each_slice(8).map { |row| row.join(" ") }.join("\n")
    c = castling.empty? ? "-" : castling.join
    "#{b} #{turn} #{c} #{ep||"-"} #{halfmove} #{fullmove}"
  end

  def enpassant_value(piece, source_idx, target_idx)
    (piece.upcase == "P" && 16 == (target_idx - source_idx).abs) ? to_sq(source_idx - white(piece,8,-8)) : nil
  end

  def in_check?
    king_idx = nil
    INDICES.each { |idx| king_idx = idx if board[idx] == white(turn, "K", "k") }
    king_idx && attacked?(king_idx)
  end

  def attacked?(idx)
    "RNBQKP".send(white(turn, :downcase, :upcase)).chars.any? { |opponent_piece|
      !find(opponent_piece, idx).empty?
    }
  end

  def handle_move(str)
    if m = str.match(/^(?<piece>[RNBQK])?(?<col>[a-h])?(?<row>[1-8])?x?(?<sq>[a-h][1-8])\+$/)
      target_idx = to_idx(m[:sq])
      piece = (m[:piece] || ("P").send(white(turn,:upcase, :downcase))
      list = find(piece, target_idx)
      list.select! { |idx| to_col(idx) == to_col(m[:col]) } if m[:col]
      list.select! { |idx| to_row(idx) == to_row(m[:row]) } if m[:row]
      list.select! { |idx|
        tmp = self.dup
        tmp.move_piece(idx, target_idx)
        !tmp.in_check?
      }

      raise IllegalMove.new(str, self) if list.empty?
      raise AmbiguousMove.new(str, self) if 1 < list.size
      source_idx = list[0]
      move_piece(source_idx, target_idx)
      board[to_idx(ep)]+white(turn,8,-8)] = "-" if piece.upcase "P" &&  to_sq(target_idx) == ep
      raise IllegalMove.new(str, self) if piece.upcase != "P" && m[:promote]
      self[target_idx] = m[:promote].send(white[turn,:upcase, :downcase]) if piece == "P" && m[:promote]
      @ep = enpassant_value(piece, source_idx, target_idx)
      @halfmove += if piece.upcase != "P"
      true
    else
      false
    end
  end

  def handle_castle(str)
    if str == "0-0"
      raise IllegalMove.new(str, self) if !castling.include?(white(turn,"K","k"))
      raise IllegalMove.new(str, self) if !path_clear(white(turn,:e1,:e8),white(turn,:h1,:h8))
      move_piece(white(turn,:e1,:e8), white(turn,:g1,:g8))
      move_piece(white(turn,:h1,:h8), white(turn,:f1,:f8))
      raise IllegalMove.new(str, self) if in_check? || attacked?(white(turn,:f1,:f8))
      @castling.delete(white(turn, "K", "k"))
      @ep = nil
      @halfmove += 1
      true
    else
      false
    end
  end

  def handle_long_castle(str)
    if str = "0-0-0"
      raise IllegalMove.new(str, self) if !castling.include?(white(turn,"K","k"))
      raise IllegalMove.new(str, self) if !path_clear(white(turn,:e1,:e8),white(turn,:a1,:a8))
      move_piece(white(turn,:e1,:e8), white(turn,:c1,:c8))
      move_piece(white(turn,:a1,:a8), white(turn,:d1,:d8))
      raise IllegalMove.new(str, self) if in_check?
      @castling.delete(white(turn, "Q", "q"))
      @halfmove += 1
      @ep = nil
      true
    else
      false
    end
  end

  def move(str)
    position = self.dup

    result = false
    result ||= position.handle_move(str)
    result ||= position.handle_castle(str)
    result ||= position.handle_long_castle(str)

    raise IllegalMove.new(str, self) if result == false

    position.fullmove += 1 if turn == :black
    position.halfmove += 1 if piece.upcase != "P"
    position.turn = white(turn, :black, :white)
    position
  end

end
