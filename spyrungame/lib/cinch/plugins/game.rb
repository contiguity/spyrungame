class Game
  attr_accessor :phase, :user_hash, :playing_user_names, :started, :locations, :actual_location, :spy_user, :votes_needed, :votes

  def initialize
    self.phase=:main
    self.user_hash = {}
    self.playing_user_names=[]
    self.started = false
    self.locations = ['Home', 'Jungle', 'Ocean', 'Large City', 'Circus', 'Large Building', 'Cave', 'Village', 'Castle']
    self.actual_location = 'Home'
    self.spy_user=nil
    self.votes_needed=0
    self.votes={}
  end

  def add_user(user)
    unless user_hash.has_key?(user.nick)#preserves join order
      user_hash[user.nick]=user
    end
  end

  def remove_user(user)
    user_hash.delete(user.nick)
  end

  def setup_game
    self.started=true
    self.playing_user_names=self.user_hash.keys.shuffle
    self.spy_user=self.user_hash[self.playing_user_names.first]
    self.actual_location=self.locations.shuffle.first
    self.votes_needed=self.playing_user_names.length/2+1
  end

  def enough_votes_for_target?(input_target)
    votes_for_target=0
    self.votes.values.each do |target|
      if target==input_target
        votes_for_target+=1
      end
    end
    votes_for_target>=self.votes_needed
  end

  def player_during_main_phase?(player_name)
    self.started && self.playing_user_names.include?(player_name) && self.phase==:main
  end

  def players_joined
    self.user_hash.keys.length
  end
end