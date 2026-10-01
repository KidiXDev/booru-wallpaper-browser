// Engine for Moebooru sites (konachan, yande.re). Port of hoshi's moebooru.rs
use super::*;

pub struct Moebooru {
    pub id: &'static str,
    pub name: &'static str,
    pub base: &'static str,
    // Drop anything not rated safe, konachan.net is the SFW mirror
    pub safe_only: bool,
}

impl Moebooru {
    fn fetch(&self, tags: &str, page: u32, limit: u32) -> Result<Vec<Value>, String> {
        let raw = send_json(
            self.id,
            get(&format!("{}/post.json", self.base))
                .query("tags", tags)
                .query("page", page.to_string())
                .query("limit", limit.to_string()),
        )?;
        match raw {
            Value::Array(posts) => Ok(posts),
            _ => Err(format!("{}: expected a list of posts", self.id)),
        }
    }

    fn map(&self, v: &Value) -> Option<Post> {
        let id = u64_of(v, "id");
        let ext = str_of(v, "file_ext");
        let keep = id > 0 && is_image(&ext) && (!self.safe_only || str_of(v, "rating") == "s");
        keep.then(|| Post {
            source: self.id,
            id,
            width: u64_of(v, "width"),
            height: u64_of(v, "height"),
            score: i64_of(v, "score"),
            rating: str_of(v, "rating"),
            tags: str_of(v, "tags"),
            ext,
            size: u64_of(v, "file_size"),
            preview: str_of(v, "preview_url"),
            sample: str_of(v, "sample_url"),
            file: str_of(v, "file_url"),
            url: format!("{}/post/show/{id}", self.base),
        })
    }
}

impl Source for Moebooru {
    fn id(&self) -> &'static str {
        self.id
    }

    fn name(&self) -> &'static str {
        self.name
    }

    fn base(&self) -> &'static str {
        self.base
    }

    fn search(&self, q: &Query) -> Result<Page, String> {
        let limit = q.limit.clamp(1, 100);
        let sort = match q.sort {
            Sort::Latest => None,
            Sort::Score => Some("order:score"),
            Sort::Random => Some("order:random"),
        };
        let raw = self.fetch(&with_sort(q.tags, sort), q.page.max(1), limit)?;
        Ok(Page {
            more: raw.len() as u32 == limit,
            posts: raw.iter().filter_map(|v| self.map(v)).collect(),
        })
    }

    fn post(&self, id: u64) -> Result<Post, String> {
        self.fetch(&format!("id:{id}"), 1, 1)?
            .iter()
            .find_map(|v| self.map(v))
            .ok_or_else(|| format!("{} post {id} not found", self.id))
    }
}

#[cfg(test)]
mod tests {
    use super::super::sources::KONACHAN_NET;

    #[test]
    fn maps_and_filters_posts() {
        let raw = serde_json::json!([
            {"id": 42, "rating": "s", "tags": "sky clouds", "file_ext": "png", "width": 1920,
             "height": 1080, "score": 7, "file_url": "https://konachan.net/image/a.png"},
            {"id": 43, "rating": "q", "file_ext": "png"},
            {"id": 44, "rating": "s", "file_ext": "gif"},
            {"rating": "s", "file_ext": "png"}
        ]);
        let posts: Vec<_> = raw.as_array().unwrap().iter().filter_map(|v| KONACHAN_NET.map(v)).collect();
        assert_eq!(posts.len(), 1);
        assert_eq!((posts[0].id, posts[0].width, posts[0].score), (42, 1920, 7));
        assert_eq!(posts[0].url, "https://konachan.net/post/show/42");
    }
}
