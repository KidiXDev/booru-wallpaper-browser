// Engine for Gelbooru-API sites (gelbooru.com and the 0.2 clones). Port of hoshi's gelbooru.rs
// (search/post only). gelbooru.com needs user_id + api_key. Pages are 0-based `pid`s
use super::*;

pub const FIELDS: &[Field] = &[
    Field { key: "user_id", label: "User ID", secret: false },
    Field { key: "api_key", label: "API key", secret: true },
];

pub struct Gelbooru {
    pub id: &'static str,
    pub name: &'static str,
    pub base: &'static str,
    pub account: Option<Account>,
}

impl Gelbooru {
    fn fetch(&self, params: &[(&str, String)], auth: &Credentials) -> Result<Vec<Value>, String> {
        require(self.name, self.account.as_ref(), auth)?;
        let mut request = get(&format!("{}/index.php", self.base))
            .query("page", "dapi")
            .query("s", "post")
            .query("q", "index")
            .query("json", "1");
        if let (Some(user), Some(key)) = (cred(auth, "user_id"), cred(auth, "api_key")) {
            request = request.query("user_id", user).query("api_key", key);
        }
        for (k, v) in params {
            request = request.query(*k, v);
        }
        let raw = send_json(self.id, request)?;
        if let Some(message) = raw.as_str() {
            return Err(format!("{}: {message}", self.id));
        }
        // 0.2 clones return a list, gelbooru.com wraps it in {"post": [...]}
        Ok(match raw {
            Value::Array(posts) => posts,
            v => v.get("post").and_then(Value::as_array).cloned().unwrap_or_default(),
        })
    }

    fn map(&self, v: &Value) -> Option<Post> {
        let id = u64_of(v, "id");
        let file = str_of(v, "file_url");
        let ext = ext_of(&file);
        if id == 0 || !is_image(&ext) {
            return None;
        }
        let sample = Some(str_of(v, "sample_url")).filter(|s| !s.is_empty()).unwrap_or_else(|| file.clone());
        Some(Post {
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
            sample,
            file,
            url: format!("{}/index.php?page=post&s=view&id={id}", self.base),
        })
    }
}

impl Source for Gelbooru {
    fn id(&self) -> &'static str {
        self.id
    }

    fn name(&self) -> &'static str {
        self.name
    }

    fn base(&self) -> &'static str {
        self.base
    }

    fn account(&self) -> Option<&Account> {
        self.account.as_ref()
    }

    fn search(&self, q: &Query) -> Result<Page, String> {
        let limit = q.limit.clamp(1, 100);
        let sort = match q.sort {
            Sort::Latest => "",
            Sort::Score => "sort:score:desc",
            Sort::Random => "sort:random",
        };
        let rating = if q.spicy { "" } else { "-rating:questionable -rating:explicit" };
        let raw = self.fetch(
            &[
                ("tags", join_tags(&[q.tags, sort, rating])),
                ("pid", (q.page.max(1) - 1).to_string()),
                ("limit", limit.to_string()),
            ],
            q.auth,
        )?;
        Ok(Page {
            more: raw.len() as u32 == limit,
            posts: raw.iter().filter_map(|v| self.map(v)).filter(|p| q.allows(&p.rating)).collect(),
        })
    }

    fn post(&self, id: u64, auth: &Credentials) -> Result<Post, String> {
        self.fetch(&[("id", id.to_string())], auth)?
            .iter()
            .find_map(|v| self.map(v))
            .ok_or_else(|| format!("{} post {id} not found", self.id))
    }
}

#[cfg(test)]
mod tests {
    use super::super::sources::SAFEBOORU;

    #[test]
    fn maps_posts() {
        let raw = serde_json::json!({
            "id": 7191992, "width": 2048, "height": 1595, "score": null, "rating": "general",
            "tags": "scenery snow", "sample": true,
            "preview_url": "https://safebooru.org/thumbnails/594/thumbnail_a.jpg",
            "sample_url": "https://safebooru.org/samples/594/sample_a.jpg",
            "file_url": "https://safebooru.org/images/594/a.jpg"
        });
        let post = SAFEBOORU.map(&raw).unwrap();
        assert_eq!((post.ext.as_str(), post.score, post.size), ("jpg", 0, 0));
        assert_eq!(post.url, "https://safebooru.org/index.php?page=post&s=view&id=7191992");
        assert!(SAFEBOORU.map(&serde_json::json!({"id": 1, "file_url": "a.webm"})).is_none());
    }
}
