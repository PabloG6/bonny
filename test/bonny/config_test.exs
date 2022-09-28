defmodule Bonny.ConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias Bonny.Config

  defmodule ConnGetter do
    def get_conn(), do: %K8s.Conn{cluster_name: "foo"}
    def get_conn(:tuple), do: {:ok, %K8s.Conn{cluster_name: "bar"}}
  end

  describe "group/0" do
    test "defaults to hyphenated app name example.com" do
      original = Application.get_env(:bonny, :group)

      Application.delete_env(:bonny, :group)
      assert Config.group() == "bonny.example.com"

      Application.put_env(:bonny, :group, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :group)

      Application.put_env(:bonny, :group, "foo-bar.example.test")
      assert Config.group() == "foo-bar.example.test"

      Application.put_env(:bonny, :group, original)
    end
  end

  describe "service_account/0" do
    test "removes invalid characters" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.put_env(:bonny, :service_account_name, "k3wl$")
      assert Config.service_account() == "k-wl-"

      Application.put_env(:bonny, :operaservice_account_nametor_name, original)
    end

    test "defaults to hyphenated app name" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.delete_env(:bonny, :service_account_name)
      assert Config.service_account() == "bonny"

      Application.put_env(:bonny, :service_account_name, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :service_account_name)

      Application.put_env(:bonny, :service_account_name, "foo-bar")
      assert Config.service_account() == "foo-bar"

      Application.put_env(:bonny, :service_account_name, original)
    end
  end

  describe "name/0" do
    test "removes invalid characters" do
      original = Application.get_env(:bonny, :operator_name)

      Application.put_env(:bonny, :operator_name, "k3wl$")
      assert Config.name() == "k-wl-"

      Application.put_env(:bonny, :operator_name, original)
    end

    test "defaults to hyphenated app name" do
      original = Application.get_env(:bonny, :operator_name)

      Application.delete_env(:bonny, :operator_name)
      assert Config.name() == "bonny"

      Application.put_env(:bonny, :operator_name, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :operator_name)

      Application.put_env(:bonny, :operator_name, "foo-bar")
      assert Config.name() == "foo-bar"

      Application.put_env(:bonny, :operator_name, original)
    end
  end

  describe "namespace/0" do
    test "returns 'default' when not set" do
      original = Application.get_env(:bonny, :namespace)

      Application.delete_env(:bonny, :namespace)
      assert Config.namespace() == "default"
      Application.put_env(:bonny, :namespace, original)
    end

    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :namespace)

      Application.put_env(:bonny, :namespace, :all)
      assert Config.namespace() == :all
      Application.put_env(:bonny, :namespace, original)
    end

    test "can be set by env variable" do
      System.put_env("BONNY_POD_NAMESPACE", "prod")
      assert Config.namespace() == "prod"
      System.delete_env("BONNY_POD_NAMESPACE")
    end

    test "can be set to :all via env variable" do
      System.put_env("BONNY_POD_NAMESPACE", "__ALL__")
      assert Config.namespace() == :all
      System.delete_env("BONNY_POD_NAMESPACE")
    end

    test "config.exs configuration is preceded by env" do
      original = Application.get_env(:bonny, :namespace)

      System.put_env("BONNY_POD_NAMESPACE", "prod")
      Application.put_env(:bonny, :namespace, "my-cool-namespace")
      assert Config.namespace() == "prod"
      System.delete_env("BONNY_POD_NAMESPACE")
      assert Config.namespace() == "my-cool-namespace"
      Application.put_env(:bonny, :namespace, original)
    end
  end

  describe "controllers/0" do
    test "must be set via config.exs" do
      original = Application.get_env(:bonny, :controllers)

      Application.put_env(:bonny, :controllers, [Test, Foo])
      assert Config.controllers() == [Test, Foo]

      Application.put_env(:bonny, :controllers, original)
    end
  end

  describe "labels/0" do
    test "can be set via config.exs" do
      original = Application.get_env(:bonny, :labels)

      Application.put_env(:bonny, :labels, %{"foo" => "bar"})
      assert Config.labels() == %{"foo" => "bar"}

      Application.put_env(:bonny, :labels, original)
    end
  end

  describe "conn/0" do
    setup do
      original = Application.get_env(:bonny, :get_conn)
      on_exit(fn -> Application.put_env(:bonny, :get_conn, original) end)
    end

    test "raises when not set" do
      Application.delete_env(:bonny, :get_conn)

      assert_raise(RuntimeError, ~r/^Check bonny.get_conn in your config.exs./, fn ->
        Config.conn()
      end)
    end

    test "works with a getter that takes no args" do
      Application.put_env(:bonny, :get_conn, {ConnGetter, :get_conn})

      conn = Config.conn()
      assert "foo" == conn.cluster_name
    end

    test "works with a getter that takes args" do
      Application.put_env(:bonny, :get_conn, {ConnGetter, :get_conn, [:tuple]})

      conn = Config.conn()
      assert "bar" == conn.cluster_name
    end
  end
end
