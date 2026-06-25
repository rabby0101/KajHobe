
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { PhoneticInput, PhoneticTextarea } from '@/components/PhoneticInput';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Checkbox } from '@/components/ui/checkbox';
import { toast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';
import { useCreateJob } from '@/hooks/useJobs';
import Header from '@/components/Header';
import { serviceCategories, categoryLabel } from '@/lib/categories';
import { useLanguage } from '@/contexts/LanguageContext';

const PostJob = () => {
  const navigate = useNavigate();
  const { user } = useAuth();
  const { language, t } = useLanguage();
  const createJobMutation = useCreateJob();
  
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    category: '',
    budget: '',
    location: '',
    urgent: false
  });

  React.useEffect(() => {
    if (!user) {
      navigate('/auth');
    }
  }, [user, navigate]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.title || !formData.description || !formData.category || !formData.budget || !formData.location) {
      toast({
        title: "Error",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      await createJobMutation.mutateAsync({
        title: formData.title,
        description: formData.description,
        category: formData.category,
        budget: Number(formData.budget),
        location: formData.location,
        urgent: formData.urgent,
        status: 'open'
      });

      toast({
        title: "Success!",
        description: "Your job has been posted successfully",
      });

      navigate('/');
    } catch (error) {
      toast({
        title: "Error",
        description: "Failed to post job. Please try again.",
        variant: "destructive",
      });
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-2xl mx-auto">
          <Card>
            <CardHeader>
              <CardTitle className="text-2xl font-bold">{t('post.title')}</CardTitle>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-6">
                <div className="space-y-2">
                  <Label htmlFor="title">{t('post.jobTitle')} *</Label>
                  <PhoneticInput
                    id="title"
                    placeholder={t('post.jobTitlePlaceholder')}
                    value={formData.title}
                    onChange={(value) => setFormData({ ...formData, title: value })}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="category">{t('post.category')} *</Label>
                  <Select value={formData.category} onValueChange={(value) => setFormData({ ...formData, category: value })}>
                    <SelectTrigger>
                      <SelectValue placeholder={t('post.selectCategory')} />
                    </SelectTrigger>
                    <SelectContent>
                      {serviceCategories.map((category) => (
                        <SelectItem key={category.id} value={category.name}>
                          <div className="flex items-center gap-2">
                            <span>{category.icon}</span>
                            <div>
                              <div>{categoryLabel(category, language)}</div>
                              <div className="text-xs text-muted-foreground">
                                {language === 'bn' ? category.name : category.bengaliName}
                              </div>
                            </div>
                          </div>
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="description">{t('post.description')} *</Label>
                  <PhoneticTextarea
                    id="description"
                    placeholder={t('post.descriptionPlaceholder')}
                    rows={4}
                    value={formData.description}
                    onChange={(value) => setFormData({ ...formData, description: value })}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="budget">{t('post.budget')} *</Label>
                  <Input
                    id="budget"
                    type="number"
                    placeholder="1000"
                    value={formData.budget}
                    onChange={(e) => setFormData({ ...formData, budget: e.target.value })}
                    required
                  />
                </div>

                <div className="space-y-2">
                  <Label htmlFor="location">{t('post.location')} *</Label>
                  <PhoneticInput
                    id="location"
                    placeholder={t('post.locationPlaceholder')}
                    value={formData.location}
                    onChange={(value) => setFormData({ ...formData, location: value })}
                    required
                  />
                </div>

                <div className="flex items-center space-x-2">
                  <Checkbox
                    id="urgent"
                    checked={formData.urgent}
                    onCheckedChange={(checked) => setFormData({ ...formData, urgent: checked as boolean })}
                  />
                  <Label htmlFor="urgent">{t('post.urgent')}</Label>
                </div>

                <Button
                  type="submit"
                  className="w-full"
                  disabled={createJobMutation.isPending}
                >
                  {createJobMutation.isPending ? t('post.submitting') : t('post.submit')}
                </Button>
              </form>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default PostJob;
