
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Switch } from '@/components/ui/switch';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Bell, Shield, User, Palette, Languages } from 'lucide-react';
import { useAuth } from '@/contexts/AuthContext';
import { useTheme } from '@/contexts/ThemeContext';
import { useLanguage } from '@/contexts/LanguageContext';
import { toast } from '@/hooks/use-toast';
import Header from '@/components/Header';
import ThemeToggle from '@/components/ThemeToggle';

const Settings = () => {
  const { signOut } = useAuth();
  const { theme } = useTheme();
  const { language, setLanguage, t } = useLanguage();

  const handleSignOut = async () => {
    try {
      await signOut();
      toast({
        title: t('settings.signedOut'),
        description: t('settings.signedOutDesc'),
      });
    } catch (error) {
      toast({
        title: t('settings.error'),
        description: t('settings.signOutError'),
        variant: "destructive",
      });
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <Header />
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-3xl font-bold text-foreground mb-8">{t('settings.title')}</h1>

          <div className="space-y-6">
            {/* Appearance Settings */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Palette className="h-5 w-5" />
                  {t('settings.appearance')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.theme')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.themeDesc')}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className="text-sm">{t(theme === 'light' ? 'theme.light' : 'theme.dark')}</span>
                    <ThemeToggle />
                  </div>
                </div>
                <Separator />
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.language')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.languageDesc')}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <Languages className="h-4 w-4" />
                    <Select value={language} onValueChange={setLanguage}>
                      <SelectTrigger className="w-32">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="en">{t('language.english')}</SelectItem>
                        <SelectItem value="bn">{t('language.bengali')}</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Notification Settings */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Bell className="h-5 w-5" />
                  {t('settings.notifications')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.emailNotifications')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.emailNotificationsDesc')}
                    </p>
                  </div>
                  <Switch defaultChecked />
                </div>
                <Separator />
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.jobAlerts')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.jobAlertsDesc')}
                    </p>
                  </div>
                  <Switch defaultChecked />
                </div>
                <Separator />
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.bidUpdates')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.bidUpdatesDesc')}
                    </p>
                  </div>
                  <Switch defaultChecked />
                </div>
              </CardContent>
            </Card>

            {/* Privacy Settings */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Shield className="h-5 w-5" />
                  {t('settings.privacy')}
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.profileVisibility')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.profileVisibilityDesc')}
                    </p>
                  </div>
                  <Switch defaultChecked />
                </div>
                <Separator />
                <div className="flex items-center justify-between">
                  <div>
                    <Label>{t('settings.showContactInfo')}</Label>
                    <p className="text-sm text-muted-foreground">
                      {t('settings.showContactInfoDesc')}
                    </p>
                  </div>
                  <Switch />
                </div>
              </CardContent>
            </Card>

            {/* Account Actions */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <User className="h-5 w-5" />
                  {t('settings.account')}
                </CardTitle>
              </CardHeader>
              <CardContent>
                <Button
                  variant="destructive"
                  onClick={handleSignOut}
                  className="w-full sm:w-auto"
                >
                  {t('settings.signOut')}
                </Button>
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Settings;
