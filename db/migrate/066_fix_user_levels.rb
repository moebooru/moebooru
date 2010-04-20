class FixUserLevels < ActiveRecord::Migration
  def self.up
    execute("UPDATE users SET level = 50 WHERE level = 20")
    execute("UPDATE users SET level = 40 WHERE level = 10")
    execute("UPDATE users SET level = 30 WHERE level = 3")
    execute("UPDATE users SET level = 20 WHERE level = 2")
    execute("UPDATE users SET level = 10 WHERE level = 0")
    execute("UPDATE users SET level = 0 WHERE Level = -1")
  end

  def self.down
    execute("UPDATE users SET level = -1 WHERE level = 0")
    execute("UPDATE users SET level = 0 WHERE level = 10")
    execute("UPDATE users SET level = 2 WHERE level = 20")
    execute("UPDATE users SET level = 3 WHERE level = 30")
    execute("UPDATE users SET level = 10 WHERE level = 40")
    execute("UPDATE users SET level = 20 WHERE Level = 50")
  end
end
