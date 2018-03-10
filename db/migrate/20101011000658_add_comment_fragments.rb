class AddCommentFragments < ActiveRecord::Migration[5.1]
  def self.up
    execute <<-EOS
      CREATE TABLE comment_fragments (
        id SERIAL PRIMARY KEY,
        comment_id integer NOT NULL REFERENCES comments ON DELETE CASCADE,
        block_id integer NOT NULL,
        source_lang text NOT NULL,
        target_lang text NOT NULL,
        body text NOT NULL,
        CONSTRAINT comment_fragments_unique UNIQUE (comment_id, block_id, source_lang, target_lang)
      );
    EOS

    add_index :comment_fragments, :comment_id

    # The user's language, eg. "en".  If NULL, the user hasn't specified a language.
    execute "ALTER TABLE users ADD COLUMN language TEXT NOT NULL DEFAULT ''"

    # A comma-separated list of languages a user doesn't need translated, eg. "ja,en".
    execute "ALTER TABLE users ADD COLUMN secondary_languages TEXT NOT NULL DEFAULT ''"

    # Created an updated_at column for comments.
    execute "ALTER TABLE comments ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT now()"
    execute "UPDATE comments set updated_at=created_at"
  end

  def self.down
    execute "DROP TABLE comment_fragments"
    execute "ALTER TABLE users DROP COLUMN language"
    execute "ALTER TABLE users DROP COLUMN secondary_languages"
    execute "ALTER TABLE comments DROP COLUMN updated_at"
  end
end
