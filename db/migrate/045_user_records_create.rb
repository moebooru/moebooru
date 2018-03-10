class UserRecordsCreate < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      create table user_records (
        id serial primary key,
        user_id integer not null references users on delete cascade,
        reported_by integer not null references users on delete cascade,
        created_at timestamp not null default now(),
        is_positive boolean not null default true,
        body text not null
      )
    EOS
  end

  def self.down
    drop_table :user_records
  end
end
