# frozen_string_literal: true

class AccountSearchService < BaseService
  attr_reader :query, :limit, :offset, :options, :account

  def call(query, account = nil, options = {})
    @query   = query.strip
    @limit   = options[:limit].to_i
    @offset  = options[:offset].to_i
    @onlyVerified = options[:onlyVerified] || false
    @options = options
    @account = account
    @group = options[:group] || nil
    @following_only = options[:following] && @account

    search_service_results
  end

  private

  def search_service_results
    return [] if query_blank_or_hashtag? || limit < 1

    if @following_only
      return @account.following.contains_display_name(@query)
        .or(@account.following.matches_username(@query))
        .limit(@limit)
    end

    search_results_and_exact_match.compact.uniq.slice(0, limit)
  end

  def resolving_non_matching_remote_account?
    options[:resolve] && !exact_match && !domain_is_local?
  end

  def search_results_and_exact_match
    exact = [exact_match]
    return exact if !exact[0].nil? && limit == 1
    exact + search_results.to_a
  end

  def query_blank_or_hashtag?
    query.blank? || query.start_with?('#')
  end

  def split_query_string
    @_split_query_string ||= query.gsub(/\A@/, '').split('@')
  end

  def query_username
    @_query_username ||= split_query_string.first || ''
  end

  def query_domain
    @_query_domain ||= query_without_split? ? nil : split_query_string.last
  end

  def query_without_split?
    split_query_string.size == 1
  end

  def domain_is_local?
    @_domain_is_local ||= true
  end

  def search_from
    options[:following] && account ? account.following : Account
  end

  def exact_match
    @_exact_match ||= begin
      search_from.without_suspended.find_local(query_username)
    end
  end

  def search_results
    @_search_results ||= begin
      if account
        advanced_search_results
      else
        simple_search_results
      end
    end
  end

  def advanced_search_results
    Account.advanced_search_for(terms_for_query, account, limit, offset, onlyVerified: @onlyVerified)
  end

  def simple_search_results
    Account.search_for(terms_for_query, limit, offset, onlyVerified: @onlyVerified)
  end

  def terms_for_query
    if domain_is_local?
      query_username
    else
      "#{query_username} #{query_domain}"
    end
  end
end
