require 'minitest/autorun'
require 'timeout'

class CustomerSuccessBalancing
  def initialize(customer_success, customers, away_customer_success)
    @customer_success = customer_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  def execute
    return 0 unless minimum_available_customer_success.present?

    @available_customer_success = find_available_customer_success

    return 0 unless available_customer_success.present?

    customers.sort! { |a, b| a[:score] <=> b[:score] }

    matching_customers_to_customer_sucess

    costumer_success_with_most_customers = find_costumer_success_with_most_customers

    tied_cs = tied_cs(costumer_success_with_most_customers)

    tied_cs ? 0 : costumer_success_with_most_customers[:id]
  end

  private

  attr_reader :customer_success, :customers, :away_customer_success, :available_customer_success

  def minimum_available_customer_success
    maximum_abstentions = customer_success.size / 2
    away_customer_success.size <= maximum_abstentions.floor
  end

  def find_available_customer_success
    available_customer_success = []

    customer_success.each do |cs|
      next if away_customer_success.include?(cs[:id])

      available_customer_success.push(cs)
    end

    available_customer_success.sort! { |a, b| a[:score] <=> b[:score] }

    available_customer_success.map do |cs|
      cs[:customers] = []
      cs
    end
  end

  def matching_customers_to_customer_sucess
    index = 0

    customers.map do |customer|
      cs = available_customer_success[index]
      matched = customer[:score] <= cs[:score]

      next cs[:customers].push(customer) if matched

      until matched
        break if available_customer_success.last == cs

        index += 1
        cs = available_customer_success[index]
        matched = customer[:score] <= cs[:score]
        cs[:customers].push(customer) if matched
      end
    end
  end

  def find_costumer_success_with_most_customers
    available_customer_success.inject(available_customer_success[0]) do |cs_with_more_clients, cs|
      customer_size(cs_with_more_clients) < customer_size(cs) ? cs : cs_with_more_clients
    end
  end

  def customer_size(customer)
    customer[:customers].size
  end

  def tied_cs(costumer_success_with_most_customers)
    available_customer_success.any? do |cs|
      same_number_of_customers = customer_size(cs) == customer_size(costumer_success_with_most_customers)
      cs[:id] != costumer_success_with_most_customers[:id] && same_number_of_customers
    end
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end
