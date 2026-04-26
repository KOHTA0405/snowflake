import os
import dlt
import requests


@dlt.resource(name="posts")
def get_posts():
    response = requests.get("https://jsonplaceholder.typicode.com/posts")
    response.raise_for_status()
    yield from response.json()


if __name__ == "__main__":
    credentials = {
        "host": os.environ["SNOWFLAKE_HOST"],
        "database": os.environ["SNOWFLAKE_DATABASE"],
        "username": os.environ["SNOWFLAKE_USER"],
        "private_key": os.environ["SNOWFLAKE_PRIVATE_KEY"],  # PEM 文字列をそのまま渡す
        "warehouse": os.environ["SNOWFLAKE_WAREHOUSE"],
        "role": os.environ["SNOWFLAKE_ROLE"],
    }

    pipeline = dlt.pipeline(
        pipeline_name="jsonplaceholder",
        destination=dlt.destinations.snowflake(credentials=credentials),
        dataset_name="raw",
    )

    info = pipeline.run(get_posts())
    print(info)
