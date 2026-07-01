# frozen_string_literal: true

class AddApprovalTokenToQuotes < ActiveRecord::Migration[8.1]
  def up
    add_column :quotes, :approval_token, :string

    execute <<~SQL.squish
      UPDATE quotes
      SET approval_token = upper(substring(md5(random()::text || id::text) || md5(random()::text), 1, 32))
      WHERE approval_token IS NULL
    SQL

    change_column_null :quotes, :approval_token, false
    add_index :quotes, :approval_token, unique: true
  end

  def down
    remove_index :quotes, :approval_token
    remove_column :quotes, :approval_token
  end
end
