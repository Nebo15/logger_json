# now = DateTime.utc_now()

inputs = [
  {"just a msg", %{message: "This is just some elaborate message"}},
  {"some map",
   %{
     message: "some other weirdo message",
     time: DateTime.utc_now(),
     http_meta: %{
       status: 500,
       method: "GET",
       headers: [["what", "eva"], ["some-more", "stuff"]]
     }
   }},
  {"bigger_map",
   %{
     "users" => %{
       "user_1" => %{
         "name" => "Alice",
         "age" => 30,
         "preferences" => %{
           "theme" => "dark",
           "language" => "English",
           "notifications" => %{
             "email" => true,
             "sms" => false,
             "push" => true
           }
         },
         "tags" => ["developer", "team_lead"]
       },
       "user_2" => %{
         "name" => "Bob",
         "age" => 25,
         "preferences" => %{
           "theme" => "light",
           "language" => "French",
           "notifications" => %{
             "email" => true,
             "sms" => true,
             "push" => false
           }
         },
         "tags" => ["designer", "remote"]
       }
     },
     "settings" => %{
       "global" => %{
         "timezone" => "UTC",
         "currency" => :usd,
         "support_contact" => "support@example.com"
       },
       "regional" => %{
         "US" => %{
           "timezone" => "America/New_York",
           "currency" => :usd
         },
         "EU" => %{
           "timezone" => "Europe/Berlin",
           "currency" => "EUR"
         }
       }
     },
     "analytics" => %{
       "page_views" => %{
         "home" => 1200,
         "about" => 450,
         "contact" => 300
       },
       "user_sessions" => %{
         "total" => 2000,
         "active" => 150
       }
     }
   }}
]

redactors = []
{_, default_formatter_config} = Logger.Formatter.new(colors: [enabled?: false])
{_, default_json_formatter_config} = LoggerJSON.Formatters.Basic.new(metadata: :all)

Benchee.run(
  %{
    "just JSON" => fn input -> JSON.encode_to_iodata!(input) end,
    "just Jason" => fn input -> Jason.encode_to_iodata!(input) end,
    "logger_json encode" => fn input ->
      %{message: LoggerJSON.Formatter.RedactorEncoder.encode(input, redactors)}
    end,
    "whole logger format" => fn input ->
      LoggerJSON.Formatters.Basic.format(%{level: :info, meta: %{}, msg: {:report, input}}, default_json_formatter_config)
    end,
    # odd that those 2 end up being the slowest - what additional work are they doing?
    "default formatter with report data (sanity check)" => fn input ->
      Logger.Formatter.format(
        %{level: :info, meta: %{}, msg: {:report, input}},
        default_formatter_config
      )
    end,
    "default formatter with pre-formatted report data  as string (sanity check 2)" =>
      {fn input ->
         Logger.Formatter.format(
           %{level: :info, meta: %{}, msg: {:string, input}},
           default_formatter_config
         )
       end, before_scenario: &inspect/1}
  },
  warmup: 0.1,
  time: 1,
  inputs: inputs
)
